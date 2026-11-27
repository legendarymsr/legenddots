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
# The LFS 'host system requirements' set (everything libre/setup's host check
# looks for — incl. flex), plus parted/dosfstools for the disk.
# GNU GRUB is built inside the target, so the builder needs no bootloader.
apt-get install -y --no-install-recommends \
  build-essential gcc g++ make bison flex gawk m4 texinfo gzip bzip2 xz-utils \
  patch perl python3 sed tar wget curl git file findutils diffutils grep \
  parted dosfstools e2fsprogs gettext pkg-config || { say "apt failed"; exit 1; }

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

# put the repo inside the target so phase 2 finds it at the documented path
say "staging repo into target:/root/legenddots"
rm -rf "$LFS/root/legenddots"; cp -a "$REPO" "$LFS/root/legenddots"

# ── PHASE 2 — desktop (Xorg, ratpoison, Emacs, …); chroot = BLFS-style ───────
say "PHASE 2 — desktop build in chroot"
chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM="${TERM:-xterm}" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}" \
  bash /root/legenddots/libre/setup || { say "phase 2 failed (resume: re-run the launcher)"; exit 1; }

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
  say "ALL DONE — libre system built on $TARGET"
  touch /mnt/work/done
fi
