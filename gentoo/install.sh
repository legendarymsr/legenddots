#!/usr/bin/env bash
# =============================================================================
# Gentoo Install Script — MacBook Air 6,2 (THE "NO-BLOAT" FINAL)
# =============================================================================
set -euo pipefail

# ── Colours & Functions ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}::${NC} $*"; }
success() { echo -e "${GREEN}ok${NC}  $*"; }
warn()    { echo -e "${YELLOW}warn${NC} $*"; }
die()     { echo -e "${RED}ERR${NC}  $*"; exit 1; }
ask()     { echo -e "${CYAN}?${NC}   $*"; }
header()  { echo -e "\n${BOLD}${BLUE}── $* ${NC}"; }

# ── Preparation ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root."
swapoff -a || true
umount -l /dev/sda* 2>/dev/null || true

# ── Configuration ───────────────────────────────────────────────────────
header "Configuration"
lsblk -d -o NAME,SIZE,MODEL | grep -v loop
ask "Target disk (e.g. sda): "
read -r DISK_NAME
DISK="/dev/${DISK_NAME}"

ask "Username: "
read -r USERNAME
[[ -n "$USERNAME" ]] || die "Username cannot be empty."

ask "Timezone (e.g. Europe/Stockholm) [Europe/Stockholm]: "
read -r TIMEZONE; TIMEZONE="${TIMEZONE:-Europe/Stockholm}"

echo -e "\n  Choose your path:"
echo "  1) TTY Only (0.6GiB RAM lifestyle)"
echo "  2) Hyprland (Wayland Bloat?)"
echo "  3) Niri     (The Scrolling Ribbon)"
echo "  4) i3       (The Honest Choice)"
ask "Choice [1]: "
read -r DE_CHOICE; DE_CHOICE="${DE_CHOICE:-1}"

# ── Partition ─────────────────────────────────────────────────────────────────
header "Partitioning $DISK"
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"EFI" "$DISK"
sgdisk --new=2:0:+8G   --typecode=2:8200 --change-name=2:"swap" "$DISK"
sgdisk --new=3:0:0     --typecode=3:8304 --change-name=3:"root" "$DISK"
partprobe "$DISK"
udevadm settle

# ── Format & Mount ────────────────────────────────────────────────────────────
mkfs.fat -F32 -n EFI "${DISK}1"
mkswap -L swap "${DISK}2"
swapon "${DISK}2"
mkfs.ext4 -F -L root "${DISK}3"

mkdir -p /mnt/gentoo
mount "${DISK}3" /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount "${DISK}1" /mnt/gentoo/boot/efi

# ── Stage3 ────────────────────────────────────────────────────────────────────
header "Unpacking Stage3"
cd /mnt/gentoo
MIRROR="https://mirror.init7.net/gentoo"
STAGE3_PATH=$(curl -s "${MIRROR}/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt" | grep -v '^#' | grep '\.tar\.xz' | awk '{print $1}' | head -1)
curl -# -O "${MIRROR}/releases/amd64/autobuilds/${STAGE3_PATH}"
tar xpf "$(basename "$STAGE3_PATH")" --xattrs-include='*.*' --numeric-owner
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# ── Mounting Pseudo-FS ────────────────────────────────────────────────────────
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run

# ── CHROOT LOGIC ──────────────────────────────────────────────────────────────
header "Starting Chroot"

cat << CHROOT_EOF > /mnt/gentoo/tmp/inside.sh
#!/bin/bash
export DEBUGINFOD_URLS=""
source /etc/profile

emerge-webrsync
eselect profile set default/linux/amd64/23.0/hardened

# Unmask Broadcom Driver & Desktop tools
mkdir -p /etc/portage/package.accept_keywords
echo "net-wireless/broadcom-sta ~amd64" >> /etc/portage/package.accept_keywords/legend
echo "gui-wm/niri ~amd64" >> /etc/portage/package.accept_keywords/legend
echo "gui-wm/hyprland ~amd64" >> /etc/portage/package.accept_keywords/legend

# make.conf
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
MAKEOPTS="-j4"
USE="hardened sasl caps pic pie ssp wireless udev policykit elogind dbus networkmanager -systemd -gnome -kde -qt5"
CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
VIDEO_CARDS="intel iris"
ACCEPT_LICENSE="*"
EOF

# Locale
echo "${TIMEZONE}" > /etc/timezone
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile

# ── KERNEL SURGERY ──
emerge sys-kernel/hardened-sources sys-kernel/genkernel sys-kernel/linux-firmware
eselect kernel set 1
cd /usr/src/linux
make defconfig
./scripts/config -d CONFIG_INTEL_MEI
./scripts/config -d CONFIG_INTEL_MEI_ME
./scripts/config -e CONFIG_EFI_STUB
./scripts/config -e CONFIG_HID_APPLE
make olddefconfig
make -j4 && make modules_install && make install
genkernel --no-clean --no-mrproper initramfs

# Essential Tools
emerge app-shells/zsh
emerge net-misc/networkmanager app-admin/sudo dev-vcs/git app-editors/neovim net-wireless/broadcom-sta sys-boot/grub

# Sudo "Mommy"
mkdir -p /etc/sudoers.d
echo 'Defaults lecture="always"' > /etc/sudoers.d/legend
echo 'Defaults lecture_msg="mommy is very proud of you~\ngood job, Legend~"' >> /etc/sudoers.d/legend
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/legend

# User setup (password is 'legendary')
useradd -m -G wheel,audio,video,usb -s /bin/zsh "${USERNAME}"
echo "${USERNAME}:legendary" | chpasswd
echo "root:legendary" | chpasswd

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

# Services
rc-update add NetworkManager default
rc-update add dbus default
rc-update add elogind default

# Optional Desktop logic (basic install)
case "${DE_CHOICE}" in
    2) emerge gui-wm/hyprland ;;
    3) emerge gui-wm/niri ;;
    4) emerge x11-wm/i3 ;;
esac

CHROOT_EOF

chmod +x /mnt/gentoo/tmp/inside.sh
chroot /mnt/gentoo /tmp/inside.sh

success "Ascension complete. Reboot into the hardened kingdom."