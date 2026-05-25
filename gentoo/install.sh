#!/usr/bin/env bash
# =============================================================================
# Gentoo Install Script — MacBook Air 6,2 (THE FINAL PERFECTION)
# =============================================================================
set -euo pipefail

# ── Colours & Functions ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }

# ── Pre-flight ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || exit 1
swapoff -a || true
umount -l /dev/sda* 2>/dev/null || true
wipefs -af /dev/sda

# ── Disk Setup ────────────────────────────────────────────────────────────────
header "Disk Management"
sgdisk --zap-all /dev/sda
sgdisk --new=1:0:+512M --typecode=1:ef00 /dev/sda
sgdisk --new=2:0:+8G   --typecode=2:8200 /dev/sda
sgdisk --new=3:0:0     --typecode=3:8304 /dev/sda
partprobe /dev/sda && udevadm settle

mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2 && swapon /dev/sda2
mkfs.ext4 -F /dev/sda3

mkdir -p /mnt/gentoo
mount /dev/sda3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount /dev/sda1 /mnt/gentoo/boot/efi

# ── Stage3 Unpack ─────────────────────────────────────────────────────────────
cd /mnt/gentoo
MIRROR="https://mirror.init7.net/gentoo"
STAGE3_PATH=$(curl -s "${MIRROR}/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt" | grep -v '^#' | grep '\.tar\.xz' | awk '{print $1}' | head -1)
curl -# -O "${MIRROR}/releases/amd64/autobuilds/${STAGE3_PATH}"
tar xpf "$(basename "$STAGE3_PATH")" --xattrs-include='*.*' --numeric-owner
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# ── CHROOT LOGIC ──────────────────────────────────────────────────────────────
cat << 'CHROOT_EOF' > /mnt/gentoo/tmp/inside.sh
#!/bin/bash
set -euo pipefail
export DEBUGINFOD_URLS=""
source /etc/profile
export PATH="/usr/sbin:/usr/local/sbin:/sbin:${PATH}"
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }

# 1. INITIALIZE PORTAGE & HARDENED PROFILE
emerge-webrsync
eselect profile set default/linux/amd64/23.0/hardened

# 2. KEYWORDS & UNMASKING
mkdir -p /etc/portage/package.accept_keywords
{
  echo "sys-kernel/hardened-sources **"
  echo "net-wireless/broadcom-sta ~amd64"
  echo "gui-wm/niri **"
  echo "gui-wm/hyprland **"
  echo "www-client/brave-browser-nightly **"
  echo "media-libs/freetype **"
} > /etc/portage/package.accept_keywords/legend

# 3. MAKE.CONF (LEGEND OPTIMIZED)
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j4"
CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
VIDEO_CARDS="intel iris"
USE="hardened sasl caps pic pie ssp wireless udev policykit elogind dbus networkmanager bluetooth pipewire -pulseaudio alsa -systemd -gnome -kde -qt5 -cups"
ACCEPT_LICENSE="*"
EOF

# 4. OVERLAYS (GURU, ANOTHER-BRAVE, HYPROVERLAY)
emerge --oneshot app-eselect/eselect-repository dev-vcs/git
eselect repository enable guru
eselect repository add another-brave-overlay git https://github.com/falbrechtskirchinger/another-brave-overlay.git || true
eselect repository add hyproverlay git https://codeberg.org/hyproverlay/hyproverlay.git || true
emaint sync --repo guru               || true  # warnings exit non-zero; ignore
emaint sync --repo another-brave-overlay || true
emaint sync --repo hyproverlay           || true

# 5. KERNEL SURGERY (TOTAL HARDENING + ANTI-ME)
emerge sys-kernel/hardened-sources sys-kernel/genkernel \
       sys-kernel/linux-firmware sys-firmware/intel-microcode
eselect kernel set 1
cd /usr/src/linux
make defconfig

# --- INTEL ME REMOVAL ---
./scripts/config -d CONFIG_INTEL_MEI
./scripts/config -d CONFIG_INTEL_MEI_ME
./scripts/config -d CONFIG_INTEL_MEI_TXE
./scripts/config -d CONFIG_INTEL_MEI_HDCP
./scripts/config -d CONFIG_INTEL_MEI_PXP

# --- HARDWARE OPTIMIZATION ---
./scripts/config -e CONFIG_DRM_I915
./scripts/config -e CONFIG_SND_HDA_CODEC_CIRRUS
./scripts/config -e CONFIG_HID_APPLE
./scripts/config -e CONFIG_BT_HCIBTUSB
./scripts/config -e CONFIG_SATA_AHCI
./scripts/config -e CONFIG_X86_INTEL_PSTATE
./scripts/config -e CONFIG_THUNDERBOLT

# --- HARDENED SECURITY ---
./scripts/config -e CONFIG_RANDOMIZE_BASE
./scripts/config -e CONFIG_RANDOMIZE_MEMORY
./scripts/config -e CONFIG_PAGE_TABLE_ISOLATION
./scripts/config -e CONFIG_MITIGATION_RETPOLINE
./scripts/config -e CONFIG_STRICT_KERNEL_RWX
./scripts/config -e CONFIG_STRICT_MODULE_RWX
./scripts/config -e CONFIG_SECURITY_LOCKDOWN_LSM
./scripts/config -d CONFIG_MODULE_SIG_FORCE

make olddefconfig
make -j4 && make modules_install && make install
genkernel --no-clean --no-mrproper initramfs

# 6. BASE SYSTEM (LEGEND SPEC)
header "Emerging Legend's Arsenal..."
echo "mba" > /etc/hostname
cat > /etc/hosts << 'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   mba.localdomain mba
EOF

groupadd -f plugdev
groupadd -f bluetooth

emerge \
  sys-apps/pciutils sys-apps/usbutils \
  net-misc/networkmanager net-wireless/wpa_supplicant \
  net-wireless/broadcom-sta net-wireless/bluez \
  app-admin/sudo sys-apps/dbus \
  sys-auth/polkit sys-apps/acpi \
  sys-power/acpid sys-power/tlp \
  sys-apps/lm-sensors app-misc/fastfetch \
  app-shells/zsh dev-vcs/git \
  app-editors/neovim media-video/pipewire \
  media-video/wireplumber x11-terms/alacritty sys-boot/grub

# 7. DESKTOP TOOLS (NIRI)
emerge gui-wm/niri www-client/brave-browser-nightly

# 8. LOCALIZATION & USER
echo "Europe/Stockholm" > /etc/timezone
emerge --config sys-libs/timezone-data
sed -i 's/keymap="us"/keymap="se"/' /etc/conf.d/keymaps
echo "sv_SE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set sv_SE.utf8
env-update && source /etc/profile

useradd -m -G wheel,audio,video,usb,plugdev,bluetooth -s /bin/zsh legend || true
echo "legend:legendary" | chpasswd
echo "root:legendary123" | chpasswd

mkdir -p /etc/sudoers.d
echo 'legend ALL=(ALL:ALL) ALL' > /etc/sudoers.d/legend
echo 'Defaults lecture_msg="mommy is very proud of you\ngood job, Legend~"' >> /etc/sudoers.d/legend
chmod 0440 /etc/sudoers.d/legend

# 9. FINALIZE

# fstab — needed so /boot/efi remounts after reboot
ROOT_UUID=$(blkid -s UUID -o value /dev/sda3)
EFI_UUID=$(blkid  -s UUID -o value /dev/sda1)
SWAP_UUID=$(blkid -s UUID -o value /dev/sda2)
{
    echo "UUID=${ROOT_UUID}  /          ext4  defaults,noatime  0 1"
    echo "UUID=${EFI_UUID}   /boot/efi  vfat  defaults,noatime  0 2"
    echo "UUID=${SWAP_UUID}  none       swap  sw                0 0"
} > /etc/fstab

# Broadcom wl — blacklist competing drivers, autoload wl at boot
cat > /etc/modprobe.d/broadcom-sta.conf << 'EOF'
blacklist brcmfmac
blacklist brcmsmac
blacklist b43
blacklist b43legacy
blacklist ssb
blacklist bcma
EOF
echo 'modules="wl"' >> /etc/conf.d/modules

# Apple keyboard fn-mode (fn keys act as F1-F12 by default)
echo "options hid_apple fnmode=2" > /etc/modprobe.d/hid_apple.conf

depmod -a

grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

rc-update add NetworkManager default
rc-update add bluetooth       default
rc-update add dbus            default
rc-update add elogind         default
rc-update add acpid           default
rc-update add tlp             default
CHROOT_EOF

# ── Execution ─────────────────────────────────────────────────────────────────
chmod +x /mnt/gentoo/tmp/inside.sh
mount --types proc proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
chroot /mnt/gentoo /tmp/inside.sh
sync
echo -e "${GREEN}The Hardened Kingdom of Legend is built. Reboot now.${NC}"