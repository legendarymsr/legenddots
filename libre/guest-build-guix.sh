#!/bin/bash
# =============================================================================
# Guix-System variant of guest-build.sh — runs INSIDE the Guix builder VM
# (started by the Shepherd service in guix-builder.scm). Same two phases as the
# Debian path, but:
#   - no apt: the LFS host toolchain comes from the Guix system profile,
#   - optional FHS: set FHS=1 to run the build inside `guix shell --emulate-fhs`
#     (Guix's own FHS compatibility). Default FHS=0 runs directly — Guix System
#     already provides /bin/sh, /usr/bin/env and the tools in PATH, which is the
#     FHS surface LFS needs on the host, and it avoids the disk-mount/chroot
#     restrictions of a `guix shell --container`.
#
# Resumable: libre/setup checkpoints internally; the Shepherd service re-runs
# this on every boot, so a resume just continues.
# =============================================================================
set -uo pipefail
say() { echo "== $(date '+%F %T') :: $*"; }
REPO=/mnt/repo
LFS=/mnt/lfs
TARGET=/dev/vdb
FHS="${FHS:-0}"

# ── optional: re-exec the whole build inside an FHS container ────────────────
# Experimental — a `guix shell --container` is a mount namespace, so the disk
# partition/mount/chroot that phase 1 does may not be permitted inside it. If
# FHS=1 wedges on mounts, fall back to FHS=0 (the default).
if [ "$FHS" = 1 ] && command -v guix >/dev/null 2>&1; then
  say "FHS=1 — re-exec inside guix shell --emulate-fhs (experimental)"
  export FHS=0
  exec guix shell --container --emulate-fhs --network --share=/dev --share=/mnt \
    gcc-toolchain make bison m4 texinfo parted dosfstools e2fsprogs util-linux \
    perl python wget git sed tar gzip xz bzip2 patch diffutils findutils grep \
    gawk coreutils pkg-config file gettext which binutils bash \
    -- bash "$0"
fi

# ── PHASE 1 — libre BASE onto the target disk ────────────────────────────────
if ! grep -qx lfs_complete "$LFS/etc/libre-setup.state" 2>/dev/null \
   && ! grep -qx lfs_complete /etc/libre-setup.state 2>/dev/null; then
  say "PHASE 1 — base system onto $TARGET (the long one)"
  LFS_DISK="$TARGET" bash "$REPO/libre/setup" || { say "phase 1 failed"; exit 1; }
else
  say "PHASE 1 already complete — skipping"
fi

# ── mount the freshly built target and chroot in for PHASE 2 ─────────────────
say "mounting target for phase 2"
mkdir -p "$LFS"
mountpoint -q "$LFS" || mount "${TARGET}3" "$LFS" || { say "cannot mount ${TARGET}3"; exit 1; }
mkdir -p "$LFS/boot/efi"; mount "${TARGET}1" "$LFS/boot/efi" 2>/dev/null || true
for d in dev dev/pts proc sys run; do
  mkdir -p "$LFS/$d"
  mount --rbind "/$d" "$LFS/$d" 2>/dev/null || mount --bind "/$d" "$LFS/$d" 2>/dev/null || true
  mount --make-rslave "$LFS/$d" 2>/dev/null || true
done

# 4 GB builder: enable the target's swap so phase 2's heavy links page, not OOM.
swapon "${TARGET}2" 2>/dev/null && say "enabled ${TARGET}2 as swap" \
  || say "note: ${TARGET}2 swap not enabled (fine if the VM has >=8G)"

say "staging repo into target:/root/legenddots"
rm -rf "$LFS/root/legenddots"; cp -a "$REPO" "$LFS/root/legenddots"

# ── PHASE 2 — desktop in chroot (BLFS-style) ─────────────────────────────────
say "PHASE 2 — desktop build in chroot"
chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM="${TERM:-xterm}" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}" \
  bash /root/legenddots/libre/setup || { say "phase 2 failed (re-run the launcher to resume)"; exit 1; }

say "cleanup — unmount target"
umount -R "$LFS" 2>/dev/null || true
say "ALL DONE — libre system built on $TARGET (via a Guix System builder)"
touch /mnt/work/done
