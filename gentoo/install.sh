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
STAGE3_PATH=$(curl -s "${MIRROR}/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt" \
    | grep -v '^#' | grep '\.tar\.xz' | awk '{print $1}' | head -1)
curl -# -O "${MIRROR}/releases/amd64/autobuilds/${STAGE3_PATH}"
tar xpf "$(basename "$STAGE3_PATH")" --xattrs-include='*.*' --numeric-owner
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# ── CHROOT LOGIC ──────────────────────────────────────────────────────────────
cat << 'CHROOT_EOF' > /mnt/gentoo/tmp/inside.sh
#!/bin/bash
set -euo pipefail
export DEBUGINFOD_URLS=""
export DEBUGINFOD_URLS_CERT_PATH=""
set +u; source /etc/profile; set -u
export PATH="/usr/sbin:/usr/local/sbin:/sbin:${PATH}"
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }

# Allow overcommit so portage fork() calls don't fail with ENOMEM
# when the live-CD RAM is under pressure during heavy package builds
echo 1 > /proc/sys/vm/overcommit_memory
echo 262144 > /proc/sys/vm/max_map_count

# 1. PORTAGE SYNC & HARDENED PROFILE
header "Syncing portage tree..."
emerge-webrsync
eselect profile set default/linux/amd64/23.0/hardened

# 2. KEYWORDS
# ACCEPT_KEYWORDS="~amd64" in make.conf already accepts all testing packages.
# Only need package.accept_keywords for the overlay wildcards so portage
# knows to trust packages from those repos.
mkdir -p /etc/portage/package.accept_keywords
{
  echo "*/*::guru ~amd64"
  echo "*/*::hyproverlay ~amd64"
  echo "*/*::another-brave-overlay ~amd64"
} > /etc/portage/package.accept_keywords/legend

# 3. MAKE.CONF
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j4"
EMERGE_DEFAULT_OPTS="--jobs=2 --load-average=3.5 --quiet-build=y --usepkg=n --getbinpkg=n --backtrack=100"
CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
VIDEO_CARDS="intel iris"
ABI_X86="64"
LLVM_TARGETS="X86"
USE="udev elogind dbus wayland alsa -systemd -gnome -kde -qt5 -cups -pulseaudio"
PYTHON_TARGETS="python3_12 python3_13 python3_14"
PYTHON_SINGLE_TARGET="python3_13"
FEATURES="ccache"
CCACHE_DIR="/var/cache/ccache"
ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"
EOF

mkdir -p /var/cache/ccache
chown -R portage:portage /var/cache/ccache

# O1 env override for slow packages — halves compile time with no practical
# runtime impact since these are build tools / shader compilers, not hot paths
mkdir -p /etc/portage/env /etc/portage/package.env
echo 'CFLAGS="-march=haswell -O1 -pipe"
CXXFLAGS="-march=haswell -O1 -pipe"' > /etc/portage/env/O1.conf
{
  echo "llvm-core/llvm O1.conf"
  echo "llvm-core/clang O1.conf"
  echo "media-libs/mesa O1.conf"
} > /etc/portage/package.env/O1

# package.use — set before any emerge so deps pick up the right flags
mkdir -p /etc/portage/package.use

# PipeWire must expose a sound-server so wireplumber can act as its session manager
echo "media-video/pipewire sound-server" > /etc/portage/package.use/pipewire

# wireplumber needs elogind for seat/session management (we have no systemd)
echo "media-video/wireplumber elogind" > /etc/portage/package.use/wireplumber

# polkit must use elogind for privilege checks on a running seat
echo "sys-auth/polkit elogind" > /etc/portage/package.use/polkit

# NetworkManager: enable nmtui/nmcli tools
echo "net-misc/networkmanager tools" > /etc/portage/package.use/networkmanager


# elogind itself needs pam so login sessions are tracked properly
echo "sys-auth/elogind pam" > /etc/portage/package.use/elogind

# Waybar needs tray support and gtk-layer-shell for Wayland
echo "gui-apps/waybar tray" > /etc/portage/package.use/waybar

# Only build JetBrains Mono; building all ~3.5GB of nerd fonts is impractical
echo "media-fonts/nerdfonts jetbrainsmono" > /etc/portage/package.use/nerdfonts


# libglvnd X flag is off by default; mesa requires libglvnd[X] for GLX/XWayland
echo "media-libs/libglvnd X" > /etc/portage/package.use/libglvnd


# Desktop X11 libs needed by GTK/pango chain on Wayland
echo "x11-libs/cairo X" > /etc/portage/package.use/xlibs
echo "x11-libs/pango X" >> /etc/portage/package.use/xlibs
echo "x11-libs/libxkbcommon X" >> /etc/portage/package.use/xlibs
echo "dev-libs/libdbusmenu gtk3" >> /etc/portage/package.use/xlibs
# cairomm/atkmm wrap cairo and need the same X flag
echo "dev-cpp/cairomm X" >> /etc/portage/package.use/xlibs
echo "dev-cpp/atkmm X" >> /etc/portage/package.use/xlibs

# 4. OVERLAYS
header "Setting up overlays..."
emerge --oneshot app-eselect/eselect-repository dev-vcs/git
eselect repository enable guru
eselect repository add another-brave-overlay git \
    https://github.com/falbrechtskirchinger/another-brave-overlay.git || true
eselect repository add hyproverlay git \
    https://codeberg.org/hyproverlay/hyproverlay.git || true
emaint sync --repo guru                  || true
emaint sync --repo another-brave-overlay || true
emaint sync --repo hyproverlay           || true

# 5. KERNEL (gentoo-sources + manual hardening; hardened-sources was removed
#    from the Gentoo tree in 2024/2025)
header "Building kernel..."
emerge sys-kernel/gentoo-sources sys-kernel/genkernel \
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

# --- MBA 6,2 HARDWARE ---
./scripts/config -e CONFIG_DRM_I915
./scripts/config -e CONFIG_SND_HDA_CODEC_CIRRUS
./scripts/config -e CONFIG_HID_APPLE
./scripts/config -e CONFIG_BT_HCIBTUSB
./scripts/config -e CONFIG_SATA_AHCI
./scripts/config -e CONFIG_X86_INTEL_PSTATE
./scripts/config -e CONFIG_THUNDERBOLT
./scripts/config -e CONFIG_USB_XHCI_HCD
./scripts/config -e CONFIG_USB_EHCI_HCD

# --- HARDENED SECURITY ---
./scripts/config -e CONFIG_RANDOMIZE_BASE
./scripts/config -e CONFIG_RANDOMIZE_MEMORY
./scripts/config -e CONFIG_PAGE_TABLE_ISOLATION
./scripts/config -e CONFIG_MITIGATION_RETPOLINE
./scripts/config -e CONFIG_RETPOLINE
./scripts/config -e CONFIG_STRICT_KERNEL_RWX
./scripts/config -e CONFIG_STRICT_MODULE_RWX
./scripts/config -e CONFIG_SECURITY_LOCKDOWN_LSM
./scripts/config -e CONFIG_SECURITY_LOCKDOWN_LSM_EARLY
./scripts/config -d CONFIG_MODULE_SIG_FORCE

make olddefconfig
make -j4 && make modules_install && make install
genkernel --no-clean --no-mrproper initramfs

# 6. BASE SYSTEM
header "Emerging base system..."
echo "mba" > /etc/hostname
cat > /etc/hosts << 'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   mba.localdomain mba
EOF

groupadd -f plugdev
groupadd -f bluetooth

emerge \
  sys-apps/pciutils \
  sys-apps/usbutils \
  sys-process/procps \
  app-misc/figlet \
  x11-apps/igt-gpu-tools \
  sys-auth/elogind \
  net-misc/networkmanager \
  net-wireless/wpa_supplicant \
  net-wireless/broadcom-sta \
  net-wireless/bluez \
  app-admin/sudo \
  sys-apps/dbus \
  sys-auth/polkit \
  sys-power/acpid \
  sys-power/tlp \
  sys-apps/lm-sensors \
  net-misc/wget \
  app-shells/zsh \
  dev-vcs/git \
  app-editors/neovim \
  media-video/pipewire \
  media-video/wireplumber \
  x11-terms/alacritty \
  llvm-core/llvm \
  llvm-core/clang \
  sys-boot/refind

# 7. DESKTOP (niri + full Wayland stack)
header "Emerging desktop..."
emerge \
  gui-wm/niri \
  gui-apps/waybar \
  gui-apps/fuzzel \
  gui-apps/swaylock \
  gui-apps/swaybg \
  gui-apps/grim \
  gui-apps/slurp \
  gui-apps/wl-clipboard \
  x11-misc/dunst \
  gui-libs/xdg-desktop-portal-wlr \
  gnome-extra/polkit-gnome \
  media-sound/pavucontrol \
  x11-misc/xdg-utils \
  x11-misc/xdg-user-dirs \
  media-fonts/nerdfonts \
  www-client/brave-browser-nightly

# 8. LOCALIZATION & USER
header "Localizing and creating user..."
echo "Europe/Stockholm" > /etc/timezone
emerge --config sys-libs/timezone-data
sed -i 's/keymap="us"/keymap="se"/' /etc/conf.d/keymaps
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "sv_SE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && set +u && source /etc/profile && set -u

useradd -m -G wheel,audio,video,input,usb,plugdev,bluetooth -s /bin/zsh legend || true
echo "legend:$(openssl passwd -6 'legendary')" | chpasswd -e
echo "root:$(openssl passwd -6 'legendary123')" | chpasswd -e

mkdir -p /etc/sudoers.d
echo 'legend ALL=(ALL:ALL) ALL' > /etc/sudoers.d/legend
echo 'Defaults lecture_msg="mommy is very proud of you\ngood job, Legend~"' \
    >> /etc/sudoers.d/legend
chmod 0440 /etc/sudoers.d/legend

# Dotfiles
su - legend -c "git clone https://github.com/legendarymsr/legenddots ~/legenddots"
su - legend -c "mkdir -p ~/Pictures/Screenshots"
su - legend -c "
    mkdir -p ~/.config/alacritty ~/.config/niri
    ln -sfn ~/legenddots/alacritty.toml       ~/.config/alacritty/alacritty.toml
    ln -sfn ~/legenddots/.zshrc               ~/.zshrc
    ln -sfn ~/legenddots/niri/config.kdl      ~/.config/niri/config.kdl
    ln -sfn ~/legenddots/niri/waybar          ~/.config/waybar
    ln -sfn ~/legenddots/niri/fuzzel          ~/.config/fuzzel
    ln -sfn ~/legenddots/niri/dunst           ~/.config/dunst
    ln -sfn ~/legenddots/niri/swaylock        ~/.config/swaylock
"

xdg-user-dirs-update || true

# 9. FINALIZE
header "Finalizing..."

# fstab
ROOT_UUID=$(blkid -s UUID -o value /dev/sda3)
EFI_UUID=$(blkid  -s UUID -o value /dev/sda1)
SWAP_UUID=$(blkid -s UUID -o value /dev/sda2)
{
    echo "UUID=${ROOT_UUID}  /          ext4  defaults,noatime  0 1"
    echo "UUID=${EFI_UUID}   /boot/efi  vfat  defaults,noatime  0 2"
    echo "UUID=${SWAP_UUID}  none       swap  sw                0 0"
} > /etc/fstab

# Broadcom wl
cat > /etc/modprobe.d/broadcom-sta.conf << 'EOF'
blacklist brcmfmac
blacklist brcmsmac
blacklist b43
blacklist b43legacy
blacklist ssb
blacklist bcma
EOF
echo 'modules="wl"' >> /etc/conf.d/modules

# Apple keyboard fn-mode
echo "options hid_apple fnmode=2" > /etc/modprobe.d/hid_apple.conf

# Backlight permissions
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/90-backlight.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF

depmod -a "$(ls /lib/modules/ | grep gentoo | sort -V | tail -1)"

# rEFInd — works natively with Apple EFI, auto-detects kernels, no config needed
refind-install --usedefault /dev/sda1

# Services
rc-update add NetworkManager default
rc-update add bluetooth       default
rc-update add dbus            default
rc-update add elogind         default
rc-update add acpid           default
rc-update add tlp             default

header "Done. The Hardened Kingdom of Legend is built."
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
echo -e "${GREEN}Reboot now: umount -R /mnt/gentoo && reboot${NC}"
