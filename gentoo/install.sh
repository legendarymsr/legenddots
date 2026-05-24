#!/usr/bin/env bash
# =============================================================================
# Gentoo Install Script — MacBook Air 6,2 (HARDENED EDITION)
# =============================================================================
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}::${NC} $*"; }
success() { echo -e "${GREEN}ok${NC}  $*"; }
warn()    { echo -e "${YELLOW}warn${NC} $*"; }
die()     { echo -e "${RED}ERR${NC}  $*"; exit 1; }
ask()     { echo -e "${CYAN}?${NC}   $*"; }

# ── Preparation ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root."

# Force clean partitions (Avoid the 'Device Busy' error)
swapoff -a || true
umount -l /dev/sda* 2>/dev/null || true

# ── User Input ────────────────────────────────────────────────────────────────
header "Configuration"
lsblk -d -o NAME,SIZE,MODEL | grep -v loop
ask "Target disk (e.g. sda): "
read -r DISK_NAME
DISK="/dev/${DISK_NAME}"
[[ -b "$DISK" ]] || die "Block device $DISK not found."

ask "Username: "
read -r USERNAME
[[ -n "$USERNAME" ]] || die "Username cannot be empty."

# ── Partition & Format ────────────────────────────────────────────────────────
header "Purging and Partitioning"
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"EFI" "$DISK"
sgdisk --new=2:0:+8G   --typecode=2:8200 --change-name=2:"swap" "$DISK"
sgdisk --new=3:0:0     --typecode=3:8304 --change-name=3:"root" "$DISK"
partprobe "$DISK"
udevadm settle

mkfs.fat -F32 -n EFI "${DISK}1"
mkswap -L swap "${DISK}2"
swapon "${DISK}2"
mkfs.ext4 -F -L root "${DISK}3"

# ── Mount ─────────────────────────────────────────────────────────────────────
header "Mounting"
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

# ── Copy DNS ──────────────────────────────────────────────────────────────────
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# ── Scripting the Chroot ──────────────────────────────────────────────────────
cat << 'LEGEND_CHROOT' > /mnt/gentoo/tmp/inside.sh
#!/bin/bash
# Bypass the unbound variable error that killed the last run
export DEBUGINFOD_URLS=""
source /etc/profile

# Sync and Profile
emerge-webrsync
# Hardened Profile (The Legend Choice)
eselect profile set default/linux/amd64/23.0/hardened

# Configure make.conf for Haswell i5-4250U
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j4"
USE="hardened sasl caps pic pie ssp wireless udev policykit elogind dbus networkmanager -systemd -gnome -kde -qt5"
CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
VIDEO_CARDS="intel iris"
INPUT_DEVICES="libinput"
ACCEPT_LICENSE="*"
EOF

# Timezone & Locale
echo "Europe/Stockholm" > /etc/timezone
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile

# ── KERNEL SURGERY (Hardened + MacBook Air 6,2 + Anti-ME) ─────────────────────
echo ":: Building Hardened Custom Kernel..."
emerge sys-kernel/hardened-sources sys-kernel/genkernel sys-kernel/linux-firmware
eselect kernel set 1
cd /usr/src/linux

# Start with a sane defconfig
make defconfig

# ── Neutralize Intel Management Engine ──
scripts/config -d CONFIG_INTEL_MEI
scripts/config -d CONFIG_INTEL_MEI_ME
scripts/config -d CONFIG_INTEL_MEI_TXE

# ── MacBook Air 6,2 Specific Hardening ──
scripts/config -e CONFIG_MHASWELL
scripts/config -e CONFIG_SND_HDA_INTEL
scripts/config -e CONFIG_SND_HDA_CODEC_CIRRUS
scripts/config -e CONFIG_HID_APPLE
scripts/config -e CONFIG_DRM_I915
scripts/config -e CONFIG_EFI_STUB
scripts/config -e CONFIG_STRICT_KERNEL_RWX
scripts/config -e CONFIG_STRICT_MODULE_RWX

# Build the beast
make olddefconfig
make -j4
make modules_install
make install
genkernel --no-clean --no-mrproper initramfs
echo ":: Kernel Hardened and ME neutralized."

# Essential Tools
emerge net-misc/networkmanager app-admin/sudo app-misc/fastfetch app-shells/zsh dev-vcs/git app-editors/neovim net-wireless/broadcom-sta

# Services
rc-update add NetworkManager default
rc-update add dbus default
rc-update add elogind default

# The "Mommy" Sudo Prompt
mkdir -p /etc/sudoers.d
echo 'Defaults lecture="always"' > /etc/sudoers.d/legend
echo 'Defaults lecture_msg="mommy is very proud of you~\ngood job, Legend~"' >> /etc/sudoers.d/legend
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/legend

# User setup
useradd -m -G wheel,audio,video,usb -s /bin/zsh "legend"
echo "legend:password" | chpasswd
echo "root:password" | chpasswd

# Bootloader
emerge sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
LEGEND_CHROOT

# ── Execution ─────────────────────────────────────────────────────────────────
chmod +x /mnt/gentoo/tmp/inside.sh
# Mount pseudo-fs then enter
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

chroot /mnt/gentoo /tmp/inside.sh

success "Installation complete. Your MacBook is now a hardened temple."