#!/usr/bin/env bash
# =============================================================================
# KISS Linux Install Script — kiss-community fork, UEFI x86_64
# Mirrors the flow of gentoo/install.sh: partition -> extract rootfs ->
# fstab -> chroot -> configure/build. Run from any Linux live environment as
# root. Compiles a kernel from source, so budget time.
#
# Reference: kisslinux.github.io/install (canonical) + kisscommunity.org/kiss/install
# =============================================================================
set -euo pipefail

# ── Colours & helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

# ── Configuration (10s prompts, sane defaults if untouched) ───────────────────
# The kiss-community rootfs release to install. Check the releases page for the
# current tag: https://codeberg.org/kiss-community/repo/releases
KISS_VER="${KISS_VER:-24.12.18}"
# The rootfs tarball is NOT signed and ships NO .sha256 asset — its checksum is
# published in the release NOTES. This is the sha256 for KISS_VER 24.12.18; bump
# both from https://codeberg.org/kiss-community/repo/releases when upgrading.
# Set empty to skip verification (not recommended).
KISS_SHA256="${KISS_SHA256:-4e5ecef56e747029d2665a038b17a156a0cffd8ba9c99a776226aaf02bd9ff72}"
# Target disk (MacBook Air 6,2 = /dev/sda, like the Gentoo installer).
if [[ -z "${DISK:-}" ]]; then
  echo -e "${CYAN}Target disk to WIPE? (10s, default: /dev/sda)${NC}"
  read -t 10 -r ANS || true; echo
  DISK="${ANS:-/dev/sda}"
fi
if [[ -z "${PRIV_ESC:-}" ]]; then
  echo -e "${CYAN}Privilege escalation tool for the installed system? [doas/sudo] (10s, default: doas)${NC}"
  read -t 10 -r ANS || true; echo
  case "${ANS,,}" in sudo) PRIV_ESC="sudo" ;; *) PRIV_ESC="doas" ;; esac
fi
if [[ -z "${INSTALL_XMONAD:-}" ]]; then
  echo -e "${CYAN}Install the XMonad desktop (Xorg + GHC/Haskell)? [yes/no] (10s, default: yes)${NC}"
  read -t 10 -r ANS || true; echo
  case "${ANS,,}" in n|no) INSTALL_XMONAD="false" ;; *) INSTALL_XMONAD="true" ;; esac
fi
HOSTNAME_="${HOSTNAME_:-kiss}"
TIMEZONE="${TIMEZONE:-America/New_York}"
# Rebuild the whole base with your CFLAGS after extracting (slow but the KISS
# way). Off by default — the stock tarball already boots.
REBUILD_WORLD="${REBUILD_WORLD:-false}"

MNT=/mnt/kiss
BASE_URL="https://codeberg.org/kiss-community/repo/releases/download/${KISS_VER}"
# Asset name on the release. Verify on the releases page if the version changes.
TARBALL="kiss-chroot-${KISS_VER}.tar.xz"

# ── Pre-flight ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "run as root"
[[ -b "$DISK" ]]  || die "$DISK is not a block device"
[[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode (this installer is UEFI-only)"
for t in sgdisk mkfs.fat mkfs.ext4 curl tar sha256sum blkid partprobe; do
  command -v "$t" >/dev/null || die "missing tool: $t"
done

echo -e "${YEL}About to ERASE ${DISK} and install KISS ${KISS_VER}. Ctrl-C now to abort.${NC}"
sleep 5

# ── Disk layout: 512M EFI + 4G swap + rest root (matches the Gentoo installer) ─
header "Partitioning ${DISK}"
swapoff -a || true
umount -R "$MNT" 2>/dev/null || true
sgdisk --zap-all "$DISK"
sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:EFI  "$DISK"
sgdisk --new=2:0:+4G   --typecode=2:8200 --change-name=2:swap "$DISK"
sgdisk --new=3:0:0     --typecode=3:8304 --change-name=3:root "$DISK"
partprobe "$DISK"; udevadm settle 2>/dev/null || sleep 2

# Partition node names differ for nvme/mmc (p1) vs sata/usb (1).
case "$DISK" in *[0-9]) P="${DISK}p" ;; *) P="${DISK}" ;; esac
EFI="${P}1"; SWAP="${P}2"; ROOT="${P}3"

header "Filesystems"
mkfs.fat -F32 "$EFI"
mkswap "$SWAP"; swapon "$SWAP"
mkfs.ext4 -F "$ROOT"

header "Mounting at ${MNT}"
mkdir -p "$MNT"
mount "$ROOT" "$MNT"
mkdir -p "$MNT/boot/efi"
mount "$EFI" "$MNT/boot/efi"

# ── Fetch, verify and unpack the rootfs (this IS the base system + chroot) ─────
header "Downloading rootfs ${TARBALL}"
cd "$MNT"
curl -fL# -O "${BASE_URL}/${TARBALL}"
if [[ -n "$KISS_SHA256" ]]; then
  header "Verifying sha256"
  echo "${KISS_SHA256}  ${TARBALL}" | sha256sum -c - || die "checksum mismatch — aborting"
else
  echo -e "${YEL}KISS_SHA256 empty — skipping checksum verification!${NC}"
fi
header "Unpacking rootfs (extracts bin/ etc/ usr/ … straight into ${MNT})"
tar xf "$TARBALL"          # no top-level dir; do NOT --strip-components
rm -f "$TARBALL"

# ── /etc/fstab from real UUIDs ────────────────────────────────────────────────
header "Generating /etc/fstab"
{
  echo "# <device>                                   <mount>   <type> <opts>          <dump> <pass>"
  printf 'UUID=%-36s /         ext4   defaults        0 1\n'  "$(blkid -s UUID -o value "$ROOT")"
  printf 'UUID=%-36s /boot/efi vfat   defaults,noatime 0 2\n' "$(blkid -s UUID -o value "$EFI")"
  printf 'UUID=%-36s none      swap   sw              0 0\n'  "$(blkid -s UUID -o value "$SWAP")"
} > "$MNT/etc/fstab"

# Network inside the chroot.
cp -L /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true

# ── Hand off to the in-chroot phase ───────────────────────────────────────────
header "Entering chroot to configure & build"
SELF_DIR="$(dirname "$(readlink -f "$0")")"
install -Dm755 "$SELF_DIR/kiss-setup.sh" "$MNT/root/kiss-setup.sh"
# Stage the XMonad config so the in-chroot phase can drop it into the user's home.
install -Dm644 "$SELF_DIR/xmonad.hs" "$MNT/root/xmonad.hs" 2>/dev/null || true
# Pass config through the environment; kiss-chroot ships inside the tarball.
export HOSTNAME_ TIMEZONE PRIV_ESC REBUILD_WORLD KISS_VER INSTALL_XMONAD
if ! "$MNT/bin/kiss-chroot" "$MNT" /root/kiss-setup.sh; then
  echo -e "${YEL}kiss-chroot could not run the setup script directly.${NC}"
  echo -e "Enter the chroot yourself and run it:\n  ${GREEN}${MNT}/bin/kiss-chroot ${MNT}${NC}\n  ${GREEN}HOSTNAME_=${HOSTNAME_} TIMEZONE=${TIMEZONE} PRIV_ESC=${PRIV_ESC} /root/kiss-setup.sh${NC}"
  exit 0
fi

header "Done"
echo -e "${GREEN}KISS installed. Unmount and reboot:${NC}"
echo "  swapoff ${SWAP}; umount -R ${MNT}; reboot"
