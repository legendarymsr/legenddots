#!/usr/bin/env bash
# =============================================================================
# Gentoo Install Script — MacBook Air 6,2 (THE FINAL HANDSHAKE)
# =============================================================================
set -euo pipefail

# ── Colours & Functions ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
header()  { echo -e "\n\033[1m\033[36m── $* \033[0m"; }

# ── Pre-flight ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || exit 1
swapoff -a || true
umount -l /dev/sda* 2>/dev/null || true

# ── Configuration ───────────────────────────────────────────────────────
lsblk -d -o NAME,SIZE,MODEL | grep -v loop
echo "? Disk (e.g. sda): "; read -r DISK_NAME
DISK="/dev/${DISK_NAME}"
echo "? Username: "; read -r USERNAME

# ── Disk Prep & Mount ─────────────────────────────────────────────────────────
header "Disk Preparation"
sgdisk --zap-all "$DISK"
sgdisk --new=1:0:+512M --typecode=1:ef00 $DISK
sgdisk --new=2:0:+8G   --typecode=2:8200 $DISK
sgdisk --new=3:0:0     --typecode=3:8304 $DISK
mkfs.fat -F32 "${DISK}1"
mkswap "${DISK}2" && swapon "${DISK}2"
mkfs.ext4 -F "${DISK}3"

mkdir -p /mnt/gentoo
mount "${DISK}3" /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount "${DISK}1" /mnt/gentoo/boot/efi

# ── Stage3 Unpack ─────────────────────────────────────────────────────────────
header "Injecting System Logic"
cd /mnt/gentoo
MIRROR="https://mirror.init7.net/gentoo"
STAGE3_PATH=$(curl -s "${MIRROR}/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt" | grep -v '^#' | grep '\.tar\.xz' | awk '{print $1}' | head -1)
curl -# -O "${MIRROR}/releases/amd64/autobuilds/${STAGE3_PATH}"
tar xpf "$(basename "$STAGE3_PATH")" --xattrs-include='*.*' --numeric-owner
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# ── CHROOT LOGIC ──────────────────────────────────────────────────────────────
cat << CHROOT_EOF > /mnt/gentoo/tmp/inside.sh
#!/bin/bash
export DEBUGINFOD_URLS=""
source /etc/profile

# 1. Essential Sync
emerge-webrsync
eselect profile set default/linux/amd64/23.0/hardened

# 2. Setup Keywords & Masking
mkdir -p /etc/portage/package.accept_keywords
{
  echo "net-wireless/broadcom-sta ~amd64"
  echo "gui-wm/niri ~amd64"
  echo "www-client/brave-browser-nightly ~amd64"
  echo "app-eselect/eselect-repository ~amd64"
} > /etc/portage/package.accept_keywords/legend

# 3. Setup Overlays (Brave + Guru)
# Install git and eselect-repo FIRST
emerge --oneshot app-eselect/eselect-repository dev-vcs/git

# Create the repo config before syncing to avoid the 'nonexistent directory' error
mkdir -p /var/db/repos/another-brave-overlay
eselect repository add another-brave-overlay git https://github.com/stefan-6cord/another-brave-overlay.git
eselect repository enable guru
emaint sync -r another-brave-overlay
emaint sync -r guru

# 4. make.conf haswell-tuned
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
MAKEOPTS="-j4"
USE="hardened sasl caps pic pie ssp wireless udev policykit elogind dbus networkmanager -systemd -gnome -kde -plasma -qt5 -qt6 -gtk -gtk3 -gtk4"
CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
VIDEO_CARDS="intel iris"
ACCEPT_LICENSE="*"
EOF

# 5. KERNEL SURGERY (Hardened + MacBook Air 6,2 + Anti-ME)
emerge sys-kernel/hardened-sources sys-kernel/genkernel sys-kernel/linux-firmware
eselect kernel set 1
cd /usr/src/linux
make defconfig
./scripts/config -d CONFIG_INTEL_MEI -d CONFIG_INTEL_MEI_ME
./scripts/config -e CONFIG_EFI_STUB -e CONFIG_HID_APPLE
make olddefconfig
make -j4 && make modules_install && make install
genkernel --no-clean --no-mrproper initramfs

# 6. Core Apps (Install sudo FIRST to fix the directory error)
emerge app-admin/sudo app-shells/zsh app-editors/neovim app-misc/fastfetch
emerge net-misc/networkmanager net-wireless/broadcom-sta sys-boot/grub

# 7. Sudo "Mommy" Config
mkdir -p /etc/sudoers.d
echo 'Defaults lecture="always"' > /etc/sudoers.d/legend
echo 'Defaults lecture_msg="mommy is very proud of you~\ngood job, Legend~"' >> /etc/sudoers.d/legend
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/legend
chmod 440 /etc/sudoers.d/legend

# 8. User & Password (CHPASSWD bypasses the interactive security checks)
useradd -m -G wheel,audio,video,usb -s /bin/zsh "${USERNAME}"
echo "${USERNAME}:legendary" | chpasswd
echo "root:legendary123" | chpasswd

# 9. DE & Browser
emerge gui-wm/niri www-client/brave-browser-nightly::another-brave-overlay

# 10. Finalize Boot
grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
rc-update add NetworkManager default
rc-update add dbus default
rc-update add elogind default
CHROOT_EOF

# ── Execution ─────────────────────────────────────────────────────────────────
chmod +x /mnt/gentoo/tmp/inside.sh
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
chroot /mnt/gentoo /tmp/inside.sh
echo -e "${GREEN}Ascension complete. Reboot into LegendOS.${NC}"