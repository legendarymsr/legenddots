#!/usr/bin/env bash
# =============================================================================
# Finish an ALREADY-installed Exherbo: build ONLY the kernel + bootloader and
# skip everything else (system config, cave sync, networking, doas). For when
# the base system is in place and you just need the box to actually boot.
#
# Run from a live environment as root:
#   DISK=/dev/vda ./finish-boot.sh          # VM (virtio disk)
#   DISK=/dev/sda ./finish-boot.sh          # real MacBook
#   KVER=7.2.8   DISK=/dev/vda ./finish-boot.sh   # pin a kernel version
#
# The kernel is always a lean, no-modules build (virtio + AHCI/NVMe + ext4/vfat +
# a framebuffer console, EFISTUB) — fast and fits a small VM disk.
# =============================================================================
set -euo pipefail
SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

RED='\033[0;31m'; GRN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }
is_mounted() { mountpoint -q "$1" 2>/dev/null || grep -q " $1 " /proc/mounts 2>/dev/null; }

# Self-update so you always run the latest kernel/bootloader logic.
if [[ -z "${FB_SELFUPDATED:-}" ]] && command -v git >/dev/null 2>&1 \
   && git -C "$SELF_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$SELF_DIR" pull --ff-only >/dev/null 2>&1; then
    export FB_SELFUPDATED=1; exec "$SELF_DIR/$(basename "$0")" "$@"
  fi
fi

DISK="${DISK:-/dev/vda}"
MNT=/mnt/exherbo
[[ $EUID -eq 0 ]] || die "run as root"
[[ -b "$DISK" ]]  || die "$DISK is not a block device"
case "$DISK" in *[0-9]) P="${DISK}p" ;; *) P="${DISK}" ;; esac
EFI="${P}1"; ROOT="${P}3"
# The root spec baked into the boot cmdline. WITHOUT an initramfs the kernel can
# NOT resolve a filesystem UUID= — only PARTUUID= (GPT) or a device node. Get the
# GPT PARTUUID here in the live env, where blkid is reliable.
ROOT_PARTUUID="$(blkid -s PARTUUID -o value "$ROOT" 2>/dev/null || true)"

# ── Mount the installed system + pseudo-filesystems (idempotent) ──────────────
header "Mounting the installed system on ${ROOT}"
mkdir -p "$MNT"
is_mounted "$MNT"      || mount "$ROOT" "$MNT"
[[ -d "$MNT/etc/paludis" || -d "$MNT/var/db/paludis" ]] || \
  die "no Exherbo install found on $ROOT — run ./install.sh first"
mkdir -p "$MNT/boot"
is_mounted "$MNT/boot" || mount "$EFI" "$MNT/boot" || die "couldn't mount the ESP ($EFI) at $MNT/boot"
cp -L /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true
is_mounted "$MNT/dev"  || { mount --rbind /dev  "$MNT/dev"  && mount --make-rslave "$MNT/dev"; }
is_mounted "$MNT/sys"  || { mount --rbind /sys  "$MNT/sys"  && mount --make-rslave "$MNT/sys"; }
is_mounted "$MNT/proc" || mount -t proc none "$MNT/proc"
is_mounted "$MNT/run"  || { mount --rbind /run  "$MNT/run"  && mount --make-rslave "$MNT/run" || true; }

# ── Stage the shared kernel+bootloader builder into the chroot ────────────────
# Same script the booted system runs to UPDATE its kernel (exherbo/kernel-boot.sh).
[ -f "$SELF_DIR/kernel-boot.sh" ] || die "kernel-boot.sh missing next to this script"
install -Dm755 "$SELF_DIR/kernel-boot.sh" "$MNT/kernel-boot.sh"

header "Entering chroot: kernel + bootloader only"
if env -i HOME=/root TERM="${TERM:-linux}" KVER="${KVER:-}" \
     ROOT_PARTUUID="${ROOT_PARTUUID:-}" ROOT_DEV="$ROOT" \
     "$(command -v chroot)" "$MNT" /bin/bash -lc '/kernel-boot.sh'; then
  header "Done"
  echo -e "${GRN}Kernel + bootloader installed. Reboot into it:${NC}"
  echo "  swapoff -a; umount -R ${MNT}; then boot the disk (./run-vm.sh with no args)"
else
  die "kernel/bootloader step failed — see the output above"
fi
