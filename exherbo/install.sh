#!/usr/bin/env bash
# =============================================================================
# Exherbo Linux Install Script — cave / paludis, exheres-0, UEFI x86_64
# Mirrors the flow of gentoo/install.sh and kiss/install.sh: partition ->
# unpack a stage -> fstab -> chroot -> sync/build. Source-based, so it compiles
# a kernel and toolchain bits — budget time. Run from any Linux live env as root.
#
# Exherbo is systemd-first: this is the ONE systemd system in legenddots. If you
# want no-systemd, that's what gentoo/ (OpenRC), kiss/ and blfs/ are for.
#
# Reference: https://exherbo.org/docs/install-guide.html
# =============================================================================
set -euo pipefail

# Capture this script's own directory NOW, before any `cd` (we cd into $MNT
# later, which would otherwise break a relative "$0").
SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# ── Colours & helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

# ── Configuration (10s prompts, sane defaults if untouched) ───────────────────
# The Exherbo stage to unpack. Stages live at https://dev.exherbo.org/stages/ —
# variants exist (glibc/musl, gcc versions). "current" is the rolling default.
STAGE_BASE="${STAGE_BASE:-https://stages.exherbo.org/x86_64-pc-linux-gnu}"
STAGE_FILE="${STAGE_FILE:-exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz}"
# Its checksum is published beside it as <file>.sha256sum; we fetch and check it.
VERIFY="${VERIFY:-true}"

if [[ -z "${DISK:-}" ]]; then
  echo -e "${CYAN}Target disk to WIPE? (10s, default: /dev/sda)${NC}"
  read -t 10 -r ANS || true; echo
  DISK="${ANS:-/dev/sda}"
fi
if [[ -z "${PRIV_ESC:-}" ]]; then
  echo -e "${CYAN}Privilege-escalation tool for the installed system? [doas/sudo] (10s, default: doas)${NC}"
  read -t 10 -r ANS || true; echo
  case "${ANS,,}" in sudo) PRIV_ESC="sudo" ;; *) PRIV_ESC="doas" ;; esac
fi
HOSTNAME_="${HOSTNAME_:-exherbo}"
TIMEZONE="${TIMEZONE:-America/New_York}"
LOCALE="${LOCALE:-en_US.UTF-8}"

MNT=/mnt/exherbo

# ── Pre-flight ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "run as root"
[[ -b "$DISK" ]]  || die "$DISK is not a block device"
[[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode (this installer is UEFI-only)"
for t in sgdisk mkfs.fat mkfs.ext4 curl tar sha256sum blkid partprobe; do
  command -v "$t" >/dev/null || die "missing tool: $t"
done

echo -e "${YEL}About to ERASE ${DISK} and install Exherbo. Ctrl-C now to abort.${NC}"
sleep 5

# ── Disk layout: 512M EFI + 4G swap + rest root (matches the other installers) ─
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
mkdir -p "$MNT/boot"
mount "$EFI" "$MNT/boot"

# ── Fetch, verify and unpack the stage ────────────────────────────────────────
header "Downloading stage ${STAGE_FILE}"
cd "$MNT"
curl -fL# -O "${STAGE_BASE}/${STAGE_FILE}"
if [[ "$VERIFY" == "true" ]]; then
  header "Verifying sha256"
  if curl -fLs -O "${STAGE_BASE}/${STAGE_FILE}.sha256sum"; then
    # the .sha256sum file names a different local filename, so match on the hash only
    WANT="$(awk '{print $1}' "${STAGE_FILE}.sha256sum" | head -1)"
    echo "${WANT}  ${STAGE_FILE}" | sha256sum -c - || die "checksum mismatch — aborting"
    rm -f "${STAGE_FILE}.sha256sum"
  else
    echo -e "${YEL}No .sha256 published for this stage — skipping verification.${NC}"
  fi
fi
header "Unpacking the stage into ${MNT}"
tar xJpf "$STAGE_FILE" -C "$MNT" --xattrs-include='*.*' --numeric-owner
rm -f "$STAGE_FILE"

# ── /etc/fstab from real UUIDs ────────────────────────────────────────────────
header "Generating /etc/fstab"
{
  echo "# <device>                                   <mount> <type> <opts>           <dump> <pass>"
  printf 'UUID=%-36s /       ext4   defaults         0 1\n'  "$(blkid -s UUID -o value "$ROOT")"
  printf 'UUID=%-36s /boot   vfat   defaults,noatime 0 2\n'  "$(blkid -s UUID -o value "$EFI")"
  printf 'UUID=%-36s none    swap   sw               0 0\n'  "$(blkid -s UUID -o value "$SWAP")"
} > "$MNT/etc/fstab"

# ── Prepare and enter the chroot ──────────────────────────────────────────────
header "Binding pseudo-filesystems + DNS"
cp -L /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true
mount --rbind /dev  "$MNT/dev"  && mount --make-rslave "$MNT/dev"
mount --rbind /sys  "$MNT/sys"  && mount --make-rslave "$MNT/sys"
mount -t proc none  "$MNT/proc"
mount --rbind /run  "$MNT/run"  && mount --make-rslave "$MNT/run" || true

header "Entering chroot to sync & build"
install -Dm755 "$SELF_DIR/exherbo-setup.sh" "$MNT/exherbo-setup.sh"
export HOSTNAME_ TIMEZONE LOCALE PRIV_ESC
# env -i gives a clean environment; Exherbo's /etc/profile sets the rest.
env -i HOME=/root TERM="${TERM:-linux}" \
    HOSTNAME_="$HOSTNAME_" TIMEZONE="$TIMEZONE" LOCALE="$LOCALE" PRIV_ESC="$PRIV_ESC" \
    "$(command -v chroot)" "$MNT" /bin/bash -lc '/exherbo-setup.sh' || {
  echo -e "${YEL}Setup couldn't run automatically. Enter the chroot and run it by hand:${NC}"
  echo -e "  ${GREEN}env -i HOME=/root TERM=\$TERM chroot ${MNT} /bin/bash${NC}"
  echo -e "  ${GREEN}source /etc/profile && HOSTNAME_=${HOSTNAME_} TIMEZONE=${TIMEZONE} PRIV_ESC=${PRIV_ESC} /exherbo-setup.sh${NC}"
  exit 0
}

header "Done"
echo -e "${GREEN}Exherbo installed. Unmount and reboot:${NC}"
echo "  swapoff ${SWAP}; umount -R ${MNT}; reboot"
