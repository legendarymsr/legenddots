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
    gcc-toolchain make bison flex m4 texinfo parted dosfstools e2fsprogs util-linux \
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

# On Guix the 'networking' service is up before DHCP has a lease, so the first
# fetches fail with a resolver error. Phase 1 already waits; a resume skips
# phase 1, so wait here and only then copy resolv.conf (a copy taken too early
# can have no nameservers, and would overwrite a working one).
say "waiting for network (DHCP/DNS) before phase 2"
for i in $(seq 1 24); do
  if wget -q --spider --timeout=10 https://www.linuxfromscratch.org/ \
     || wget -q --spider --timeout=10 https://www.x.org/; then
    say "network is up"
    break
  fi
  [ "$i" = 1 ] && say "waiting for DHCP…"
  sleep 5
done

# The target has no /etc/resolv.conf of its own, and without one glibc only
# asks 127.0.0.1 — so DNS (hence every phase-2 download) fails in the chroot.
# Hand it the builder's resolvers; refreshed each run, and a resolv.conf that
# didn't come from here (one you wrote in the target) is left alone.
if [ ! -e "$LFS/etc/resolv.conf" ] || grep -q '^# libre-builder:' "$LFS/etc/resolv.conf" 2>/dev/null; then
  rm -f "$LFS/etc/resolv.conf"
  { echo "# libre-builder: copied from the builder VM for the phase-2 chroot"; grep -v '^#' /etc/resolv.conf; } > "$LFS/etc/resolv.conf"
  if ! awk '/^nameserver/ && $2 !~ /^127\./ { found=1 } END { exit !found }' "$LFS/etc/resolv.conf"; then
    echo "nameserver 10.0.2.3" >> "$LFS/etc/resolv.conf"
    say "no non-loopback nameserver in the builder copy — added 10.0.2.3 (QEMU user-net DNS)"
  fi
  say "target /etc/resolv.conf: $(grep -c '^nameserver' "$LFS/etc/resolv.conf") nameserver(s) from the builder"
fi

say "staging repo into target:/root/legenddots"
rm -rf "$LFS/root/legenddots"; cp -a "$REPO" "$LFS/root/legenddots"

# ── PHASE 2 — desktop in chroot (BLFS-style) ─────────────────────────────────
say "PHASE 2 — desktop build in chroot"
chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM="${TERM:-xterm}" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}" \
  bash /root/legenddots/libre/setup || { say "phase 2 failed (re-run the launcher to resume)"; exit 1; }

# Don't claim the build is finished if optional tools setup is supposed to
# install are missing (a failed xdm/fastfetch fetch used to still print
# ALL DONE and leave a done-marker, so a plain re-run exited as "Already built").
pending=""
# command(1) is a shell builtin. `env -i … command -v` execs a non-existent
# binary and always failed, so a successful xdm/fastfetch still looked missing.
for s in xdm fastfetch; do
  chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    /bin/bash -c 'command -v "$1" >/dev/null' bash "$s" \
    || pending="${pending}${s}\n"
done


# Record the boot-init stamp on the builder work dir (9p shares it to the host;
# in SHARE=copy only the log line reaches the host).
if [ -f "$LFS/etc/shepherd/boot-init.version" ]; then
  ver=$(tr -d '[:space:]' < "$LFS/etc/shepherd/boot-init.version")
  mkdir -p /mnt/work
  printf '%s\n' "$ver" > /mnt/work/boot-init.version
  say "LIBRE-BOOT-INIT: $ver"
fi

say "cleanup — unmount target"
umount -R "$LFS" 2>/dev/null || true

if [ -n "$pending" ]; then
  printf '%b' "$pending" > /mnt/work/pending
  list=$(printf '%b' "$pending" | tr '\n' ' ')
  say "optional packages not installed: $list"
  say "LIBRE-PENDING: $list"
  say "re-run the launcher to retry just those (setup will resume)"
else
  rm -f /mnt/work/pending
  say "ALL DONE — libre system built on $TARGET (via a Guix System builder)"
  touch /mnt/work/done
fi
