#!/bin/bash
# =============================================================================
# Runs INSIDE the disposable Debian builder VM (invoked by cloud-init from
# libre/run-vm.sh). Builds the whole GNU/Linux-libre system onto /dev/vdb:
# PHASE 1 (base) natively, then PHASE 2 (desktop) in a chroot of the result.
#
# Idempotent / resumable: libre/setup checkpoints internally, so re-running
# simply continues where it stopped. Not meant to be run by hand — run
# libre/run-vm.sh on the host, which shares this repo in and calls this.
# =============================================================================
set -uo pipefail
say() { echo "== $(date '+%F %T') :: $*"; }
REPO=/mnt/repo                 # this git repo: 9p share (ro) or unpacked snapshot
LFS=/mnt/lfs                   # the target root gets mounted here
TARGET=/dev/vdb

say "installing LFS host build tools"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# rEFInd: libre/setup runs `refind-install --usedefault` onto the TARGET's ESP;
# don't let the package's postinst try to install it onto the builder itself.
echo 'refind refind/install_to_esp boolean false' | debconf-set-selections
# The LFS 'host system requirements' set (everything libre/setup's host check
# looks for — incl. flex), plus parted/dosfstools for the disk and refind.
apt-get install -y --no-install-recommends \
  build-essential gcc g++ make bison flex gawk m4 texinfo gzip bzip2 xz-utils \
  patch perl python3 sed tar wget curl git file findutils diffutils grep \
  parted dosfstools e2fsprogs gettext pkg-config refind || { say "apt failed"; exit 1; }

# ── PHASE 1 — build the libre BASE onto the target disk ──────────────────────
if ! grep -qx lfs_complete "$LFS/etc/libre-setup.state" 2>/dev/null \
   && ! grep -qx lfs_complete /etc/libre-setup.state 2>/dev/null; then
  say "PHASE 1 — base system onto $TARGET (this is the long one)"
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

# 4 GB builder: enable the target's swap (vdb2) so phase 2's heavy links
# (LLVM, Mesa, Emacs) page instead of OOM-killing. No-op/harmless on a big VM.
swapon "${TARGET}2" 2>/dev/null && say "enabled ${TARGET}2 as swap" \
  || say "note: ${TARGET}2 swap not enabled (fine if you gave the VM >=8G)"

# put the repo inside the target so phase 2 finds it at the documented path
say "staging repo into target:/root/legenddots"
rm -rf "$LFS/root/legenddots"; cp -a "$REPO" "$LFS/root/legenddots"

# ── PHASE 2 — desktop (Xorg, ratpoison, Emacs, …); chroot = BLFS-style ───────
say "PHASE 2 — desktop build in chroot"
chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM="${TERM:-xterm}" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}" \
  bash /root/legenddots/libre/setup || { say "phase 2 failed (resume: re-run the launcher)"; exit 1; }

say "cleanup — unmount target"
umount -R "$LFS" 2>/dev/null || true
say "ALL DONE — libre system built on $TARGET"
touch /mnt/work/done
