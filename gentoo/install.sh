#!/usr/bin/env bash
# =============================================================================
# Gentoo Install Script — MacBook Air 6,2 (MID-2013 | Intel i5-4250U)
# =============================================================================
# HARDENED EDITION: Built from sys-kernel/hardened-sources.
# NEUTRALIZED: Intel ME interface removed at the kernel level.
# OPTIMIZED: Native Haswell/Iris instructions enabled.
# LOCALIZED: Europe/Stockholm Time + Swedish (SE) Keymap.
# =============================================================================
set -euo pipefail

# ── Colours & Header ──────────────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'
header() { echo -e "\n${BOLD}${CYAN}── $* ${NC}"; }

# ── Root & Pre-flight ─────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || { echo "ERR: Run as root"; exit 1; }
swapoff -a || true
umount -l /dev/sda* 2>/dev/null || true

# ── Hardware Verification ─────────────────────────────────────────────────────
header "Hardware check"
cat /sys/class/dmi/id/product_name | grep -qi "MacBookAir6" || \
    { echo "WARN: Not identified as Air 6,x. Use with caution."; }

# ── Configuration ─────────────────────────────────────────────────────────────
lsblk -d -o NAME,SIZE,MODEL | grep -v loop
echo -e "\n? Target disk (e.g. sda): "; read -r DISK_NAME
DISK="/dev/${DISK_NAME}"
echo -e "? Username: "; read -r USERNAME

# ── Disk Preparation ──────────────────────────────────────────────────────────
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
sgdisk --new=1:0:+512M --typecode=1:ef00 "$DISK" # EFI
sgdisk --new=2:0:+8G   --typecode=2:8200 "$DISK" # SWAP
sgdisk --new=3:0:0     --typecode=3:8304 "$DISK" # ROOT
partprobe "$DISK" && udevadm settle

mkfs.fat -F32 "${DISK}1"
mkswap -L swap "${DISK}2" && swapon "${DISK}2"
mkfs.ext4 -F -L root "${DISK}3"

mkdir -p /mnt/gentoo
mount "${DISK}3" /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount "${DISK}1" /mnt/gentoo/boot/efi

# ── Stage3 Extraction ─────────────────────────────────────────────────────────
header "Downloading & Extracting Stage3"
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
export PS1="(chroot) \$PS1"

# 1. ARCHITECTURAL PURE SYNC
emerge-webrsync
eselect profile set default/linux/amd64/23.0/hardened

# 2. KEYWORDS & UNMASKING (Everything for Legend)
mkdir -p /etc/portage/package.accept_keywords
{
  echo "net-wireless/broadcom-sta ~amd64"
  echo "gui-wm/niri **"
  echo "gui-wm/hyprland **"
  echo "www-client/brave-browser-nightly **"
  echo "media-libs/freetype **"
} > /etc/portage/package.accept_keywords/legend

# 3. OVERLAYS (GURU, HYPROVERLAY, GENTOO-ZH)
# another-brave-overlay is falbrechtskirchinger/another-brave-overlay
emerge --oneshot app-eselect/eselect-repository dev-vcs/git
eselect repository enable guru
eselect repository enable another-brave-overlay
eselect repository add hyproverlay git https://codeberg.org/hyproverlay/hyproverlay.git
emaint sync -repo guru
emaint sync -repo another-brave-overlay
emaint sync -repo hyproverlay

# 4. STOCKHOLM SETTINGS
echo "Europe/Stockholm" > /etc/timezone
emerge --config sys-libs/timezone-data
echo "sv_SE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set sv_SE.utf8
sed -i 's/keymap="us"/keymap="se"/' /etc/conf.d/keymaps

# 5. MAKE.CONF (Legend Hardened / Haswell Optimized)
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
MAKEOPTS="-j4"
VIDEO_CARDS="intel iris"

# Total Purge USE Flags
USE="bluetooth pipewire -pulseaudio alsa wireless udev policykit \
     X wayland elogind dbus networkmanager hardened sasl caps pic pie ssp \
     -systemd -gnome -kde -qt5 -cups -geolocation -gtk -gtk3 -gtk4"

ACCEPT_LICENSE="*"
GRUB_PLATFORMS="efi-64"
EOF

# 6. KERNEL SURGERY (Hardened sources + MBA Optimization)
emerge sys-kernel/hardened-sources sys-kernel/genkernel sys-kernel/linux-firmware
eselect kernel set 1
cd /usr/src/linux
make defconfig

# --- INTEL ME DISABLE ---
./scripts/config -d CONFIG_INTEL_MEI
./scripts/config -d CONFIG_INTEL_MEI_ME
./scripts/config -d CONFIG_INTEL_MEI_TXE
./scripts/config -d CONFIG_INTEL_MEI_HDCP
./scripts/config -d CONFIG_INTEL_MEI_PXP

# --- HARDWARE & HARDENING ---
./scripts/config -e CONFIG_DRM_I915
./scripts/config -e CONFIG_SND_HDA_CODEC_CIRRUS
./scripts/config -e CONFIG_HID_APPLE
./scripts/config -e CONFIG_BT_HCIBTUSB
./scripts/config -e CONFIG_SATA_AHCI
./scripts/config -e CONFIG_X86_INTEL_PSTATE
./scripts/config -e CONFIG_THUNDERBOLT
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

# 7. BASE SYSTEM & DESKTOPS
emerge sys-apps/pciutils sys-apps/usbutils net-misc/networkmanager net-wireless/wpa_supplicant \
       net-wireless/broadcom-sta net-wireless/bluez app-admin/sudo sys-apps/dbus sys-auth/polkit \
       sys-apps/acpi sys-power/acpid sys-power/tlp sys-apps/lm-sensors app-misc/fastfetch \
       app-shells/zsh dev-vcs/git app-editors/neovim media-video/pipewire media-video/wireplumber \
       x11-terms/alacritty sys-boot/grub 

# Optional Desktop Components
eselect repository enable another-brave-overlay && emaint sync -r another-brave-overlay
emerge gui-wm/niri www-client/brave-browser-nightly

# 8. THE HANDSHAKE
echo "root:legendary123" | chpasswd
useradd -m -G wheel,audio,video,usb,plugdev,bluetooth -s /bin/zsh "${USERNAME}"
echo "${USERNAME}:legendary" | chpasswd
mkdir -p /etc/sudoers.d
echo 'Defaults lecture_msg="mommy is very proud of you~\ngood job, Legend~"' > /etc/sudoers.d/legend
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/legend
chmod 0440 /etc/sudoers.d/legend

# 9. FINALIZE BOOT
grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
rc-update add NetworkManager default
rc-update add dbus default
rc-update add elogind default
rc-update add acpid default
rc-update add tlp default
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
echo -e "${GREEN}The Hardened kernel is yours. Reboot now.${NC}"