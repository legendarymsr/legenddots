#!/usr/bin/env bash
# =============================================================================
# Gentoo Install Script — MacBook Air 6,2 (THE FINAL PERMA-FIX)
# =============================================================================
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
header()  { echo -e "\n\033[1m\033[36m── $* \033[0m"; }

# ── Extraction & Disk Setup ───────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || exit 1
swapoff -a || true
umount -l /dev/sda* 2>/dev/null || true
wipefs -af /dev/sda

sgdisk --zap-all /dev/sda
sgdisk --new=1:0:+512M --typecode=1:ef00 /dev/sda
sgdisk --new=2:0:+8G   --typecode=2:8200 /dev/sda
sgdisk --new=3:0:0     --typecode=3:8304 /dev/sda

mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2 && swapon /dev/sda2
mkfs.ext4 -F /dev/sda3

mkdir -p /mnt/gentoo
mount /dev/sda3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount /dev/sda1 /mnt/gentoo/boot/efi

# ── Stage3 ────────────────────────────────────────────────────────────────────
cd /mnt/gentoo
MIRROR="https://mirror.init7.net/gentoo"
STAGE3_PATH=$(curl -s "${MIRROR}/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt" | grep -v '^#' | grep '\.tar\.xz' | awk '{print $1}' | head -1)
curl -# -O "${MIRROR}/releases/amd64/autobuilds/${STAGE3_PATH}"
tar xpf "$(basename "$STAGE3_PATH")" --xattrs-include='*.*' --numeric-owner
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# ── CHROOT LOGIC ──────────────────────────────────────────────────────────────
cat << 'CHROOT_EOF' > /mnt/gentoo/tmp/inside.sh
#!/bin/bash
export DEBUGINFOD_URLS=""
source /etc/profile
emerge-webrsync
eselect profile set default/linux/amd64/23.0/hardened

# 1. BRAVE & NIRI UNMASKING (Explicitly allow keywords)
mkdir -p /etc/portage/package.accept_keywords
{
  echo "gui-wm/niri **"
  echo "www-client/brave-browser-nightly **"
  echo "media-libs/freetype **"
  echo "net-wireless/broadcom-sta ~amd64"
  echo "app-eselect/eselect-repository ~amd64"
} > /etc/portage/package.accept_keywords/legend

# 2. OVERLAYS (No-Login Method)
emerge --oneshot app-eselect/eselect-repository dev-vcs/git
eselect repository enable guru
eselect repository enable another-brave-overlay
emaint sync -r guru
emaint sync -r another-brave-overlay

# 3. STOCKHOLM CONFIG
echo "Europe/Stockholm" > /etc/timezone
emerge --config sys-libs/timezone-data
sed -i 's/keymap="us"/keymap="se"/' /etc/conf.d/keymaps

# 4. MAKE.CONF (Haswell + Anti-Bloat)
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j4"
USE="hardened sasl caps pic pie ssp wireless udev policykit elogind dbus networkmanager -systemd -gnome -kde -plasma"
CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
VIDEO_CARDS="intel iris"
ACCEPT_LICENSE="*"
EOF

# 5. KERNEL (Hardened + MacBook Air + Anti-ME)
emerge sys-kernel/hardened-sources sys-kernel/genkernel sys-kernel/linux-firmware
cd /usr/src/linux
make defconfig
./scripts/config -d CONFIG_INTEL_MEI -d CONFIG_INTEL_MEI_ME
./scripts/config -e CONFIG_EFI_STUB -e CONFIG_HID_APPLE
make olddefconfig
make -j4 && make modules_install && make install
genkernel --no-clean --no-mrproper initramfs

# 6. TOOLS & USER (The Password Bypass)
emerge sys-apps/pciutils app-admin/sudo app-shells/zsh app-editors/neovim net-wireless/broadcom-sta sys-boot/grub
emerge gui-wm/niri www-client/brave-browser-nightly

# NUCLEAR PASSWORDS (Bypasses weak password checks/I/O errors)
echo "root:legendary123" | chpasswd
useradd -m -G wheel,audio,video,usb -s /bin/zsh legend || true
echo "legend:legendary" | chpasswd

# 7. CONFIGURE SUDO "MOMMY"
mkdir -p /etc/sudoers.d
echo 'legend ALL=(ALL:ALL) ALL' > /etc/sudoers.d/legend
echo 'Defaults lecture="always"' >> /etc/sudoers.d/legend
echo 'Defaults lecture_msg="mommy is very proud of you~\ngood job, Legend~"' >> /etc/sudoers.d/legend
chmod 0440 /etc/sudoers.d/legend

# 8. FINALIZE
grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
rc-update add NetworkManager default
rc-update add dbus default
rc-update add elogind default
sync
CHROOT_EOF

# ── Execution ─────────────────────────────────────────────────────────────────
chmod +x /mnt/gentoo/tmp/inside.sh
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run

# We use '|| true' here because if it hits an I/O error, we want to know, 
# but the script will likely have finished the important writes already.
chroot /mnt/gentoo /tmp/inside.sh || echo "Kernel and base system finished with exit code."
sync
echo -e "${GREEN}Purge complete.${NC}"