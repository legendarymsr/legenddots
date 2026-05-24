#!/usr/bin/env bash
# =============================================================================
# Gentoo Install Script — MacBook Air 6,2 (Mid 2013, Intel Core i5-4250U)
# =============================================================================
# Run this from the Gentoo minimal install CD (booted in UEFI mode).
# The script will ask questions then do everything unattended.
#
# Usage:
#   bash install.sh
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
header()  { echo -e "\n${BOLD}${BLUE}── $* ${NC}"; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root."

# ── Hardware fingerprint ──────────────────────────────────────────────────────
header "Hardware check"
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
info "DMI product: $PRODUCT"
if ! grep -qi "macbookair6" /sys/class/dmi/id/product_name 2>/dev/null; then
    warn "DMI doesn't identify this as a MacBook Air 6,x."
    warn "The script is tuned for that model. Proceed anyway? (y/N)"
    read -r CONT; [[ "$CONT" =~ ^[Yy]$ ]] || exit 0
fi

WIFI_DEV=$(lspci | grep -i broadcom | head -1 || echo "")
[[ -n "$WIFI_DEV" ]] && info "Broadcom WiFi detected: $WIFI_DEV" \
                      || warn "No Broadcom device found — WiFi driver step may need adjustment."

# ── Interactive options ───────────────────────────────────────────────────────
header "Configuration"

# Disk
echo ""; lsblk -d -o NAME,SIZE,MODEL | grep -v loop
ask "Target disk (e.g. sda): "
read -r DISK_NAME
DISK="/dev/${DISK_NAME}"
[[ -b "$DISK" ]] || die "Block device $DISK not found."

# Filesystem
ask "Root filesystem — ext4 or btrfs? [ext4]: "
read -r FS_TYPE; FS_TYPE="${FS_TYPE:-ext4}"
[[ "$FS_TYPE" == "ext4" || "$FS_TYPE" == "btrfs" ]] || die "Must be ext4 or btrfs."

# Swap
ask "Swap size in GiB (0 to skip, recommended 8 for 8GB RAM): "
read -r SWAP_SIZE; SWAP_SIZE="${SWAP_SIZE:-8}"

# System details
ask "Hostname [mba]: "
read -r HOSTNAME; HOSTNAME="${HOSTNAME:-mba}"

ask "Username: "
read -r USERNAME
[[ -n "$USERNAME" ]] || die "Username cannot be empty."

ask "Timezone (e.g. Europe/Stockholm) [UTC]: "
read -r TIMEZONE; TIMEZONE="${TIMEZONE:-UTC}"

# Desktop
echo ""
echo "  Desktop environment:"
echo "  1) None (TTY only)"
echo "  2) Hyprland (Wayland)"
echo "  3) niri   (Wayland)"
echo "  4) i3     (X11)"
ask "Choice [1]: "
read -r DE_CHOICE; DE_CHOICE="${DE_CHOICE:-1}"

# Dotfiles
ask "Clone legenddots dotfiles for the new user? (y/N): "
read -r WANT_DOTS; WANT_DOTS="${WANT_DOTS:-n}"

# Confirm
header "Summary"
echo "  Disk      : $DISK  ← WILL BE ERASED"
echo "  Filesystem: $FS_TYPE"
echo "  Swap      : ${SWAP_SIZE}GiB"
echo "  Hostname  : $HOSTNAME"
echo "  User      : $USERNAME"
echo "  Timezone  : $TIMEZONE"
echo "  Desktop   : $DE_CHOICE"
echo "  Dotfiles  : $WANT_DOTS"
echo ""
warn "ALL DATA ON $DISK WILL BE DESTROYED. Type 'yes' to continue."
read -r CONFIRM; [[ "$CONFIRM" == "yes" ]] || exit 0

# ── Partition ─────────────────────────────────────────────────────────────────
header "Partitioning $DISK"

sgdisk --zap-all "$DISK"
sgdisk --new=1:0:+512M  --typecode=1:ef00 --change-name=1:"EFI"  "$DISK"
if [[ "$SWAP_SIZE" -gt 0 ]]; then
    sgdisk --new=2:0:+"${SWAP_SIZE}G" --typecode=2:8200 --change-name=2:"swap" "$DISK"
    sgdisk --new=3:0:0                --typecode=3:8304 --change-name=3:"root" "$DISK"
    PART_EFI="${DISK}1"
    PART_SWAP="${DISK}2"
    PART_ROOT="${DISK}3"
else
    sgdisk --new=2:0:0                --typecode=2:8304 --change-name=2:"root" "$DISK"
    PART_EFI="${DISK}1"
    PART_SWAP=""
    PART_ROOT="${DISK}2"
fi

# Handle nvme naming (nvme0n1p1 vs sda1)
if [[ "$DISK" == *nvme* ]]; then
    PART_EFI="${DISK}p1"
    [[ -n "$PART_SWAP" ]] && PART_SWAP="${DISK}p2"
    PART_ROOT="${DISK}p$([[ "$SWAP_SIZE" -gt 0 ]] && echo 3 || echo 2)"
fi

partprobe "$DISK"
success "Partitioned."

# ── Format ────────────────────────────────────────────────────────────────────
header "Formatting"

mkfs.fat -F32 -n EFI "$PART_EFI"
[[ -n "$PART_SWAP" ]] && { mkswap -L swap "$PART_SWAP"; swapon "$PART_SWAP"; }

case "$FS_TYPE" in
    ext4)  mkfs.ext4  -L root "$PART_ROOT" ;;
    btrfs) mkfs.btrfs -L root "$PART_ROOT" ;;
esac

success "Formatted."

# ── Mount ─────────────────────────────────────────────────────────────────────
header "Mounting"
mkdir -p /mnt/gentoo
mount "$PART_ROOT" /mnt/gentoo

if [[ "$FS_TYPE" == "btrfs" ]]; then
    # Create subvolumes before anything else is mounted under the root
    btrfs subvolume create /mnt/gentoo/@
    btrfs subvolume create /mnt/gentoo/@home
    btrfs subvolume create /mnt/gentoo/@snapshots
    umount /mnt/gentoo
    mount -o defaults,compress=zstd,subvol=@ "$PART_ROOT" /mnt/gentoo
    mkdir -p /mnt/gentoo/{home,.snapshots}
    mount -o defaults,compress=zstd,subvol=@home      "$PART_ROOT" /mnt/gentoo/home
    mount -o defaults,compress=zstd,subvol=@snapshots "$PART_ROOT" /mnt/gentoo/.snapshots
fi

# Mount EFI after btrfs subvolume setup (avoids "device busy" on umount)
mkdir -p /mnt/gentoo/boot/efi
mount "$PART_EFI" /mnt/gentoo/boot/efi

success "Mounted."

# ── Stage3 ────────────────────────────────────────────────────────────────────
header "Downloading stage3"
cd /mnt/gentoo

MIRROR="https://mirror.init7.net/gentoo"
STAGE3_PATH=$(curl -s "${MIRROR}/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt" \
    | grep -v '^#' | awk '{print $1}' | head -1)
STAGE3_URL="${MIRROR}/releases/amd64/autobuilds/${STAGE3_PATH}"

info "Fetching: $STAGE3_URL"
curl -# -O "$STAGE3_URL"
curl -# -O "${STAGE3_URL}.asc"
curl -# -O "${STAGE3_URL}.sha256"

sha256sum -c "$(basename "${STAGE3_URL}").sha256" || die "Stage3 checksum failed."
tar xpf "$(basename "$STAGE3_URL")" --xattrs-include='*.*' --numeric-owner
success "Stage3 extracted."

# ── make.conf ─────────────────────────────────────────────────────────────────
header "Configuring make.conf"
cat > /mnt/gentoo/etc/portage/make.conf << 'MAKECONF'
# ── Compiler flags (Haswell / Intel Core i5-4250U) ───────────────────────────
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# ── CPU flags (Haswell) ───────────────────────────────────────────────────────
CPU_FLAGS_X86="aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"

# ── Parallelism (2 cores / 4 threads) ────────────────────────────────────────
MAKEOPTS="-j4"
EMERGE_DEFAULT_OPTS="--jobs=4 --load-average=3.5 --with-bdeps=y --keep-going"

# ── Portage ───────────────────────────────────────────────────────────────────
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"
GENTOO_MIRRORS="https://mirror.init7.net/gentoo https://mirror.leaseweb.com/gentoo/"

# ── USE flags ─────────────────────────────────────────────────────────────────
USE="bluetooth pipewire pulseaudio alsa wifi udev policykit \
     X wayland elogind dbus networkmanager \
     -systemd -gnome -kde -qt5 -cups -geolocation \
     jpeg png svg webp gif tiff \
     ssl nls unicode"

# ── Input devices ─────────────────────────────────────────────────────────────
INPUT_DEVICES="libinput"
VIDEO_CARDS="intel i965"

# ── Misc ──────────────────────────────────────────────────────────────────────
ACCEPT_LICENSE="* -@EULA"
ACCEPT_KEYWORDS="amd64"
GRUB_PLATFORMS="efi-64"
LC_MESSAGES=C.utf8
MAKECONF

success "make.conf written."

# ── Portage repos ─────────────────────────────────────────────────────────────
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf \
   /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# ── DNS ───────────────────────────────────────────────────────────────────────
cp /etc/resolv.conf /mnt/gentoo/etc/

# ── Broadcom WiFi licence ─────────────────────────────────────────────────────
mkdir -p /mnt/gentoo/etc/portage/package.license
echo "net-wireless/broadcom-sta Broadcom" \
    > /mnt/gentoo/etc/portage/package.license/broadcom-sta

# ── fstab (generated here with blkid — genfstab is Arch-only) ────────────────
header "Generating fstab"
ROOT_UUID=$(blkid -s UUID -o value "$PART_ROOT")
EFI_UUID=$(blkid -s UUID -o value "$PART_EFI")
ROOT_OPTS="defaults,noatime"
[[ "$FS_TYPE" == "btrfs" ]] && ROOT_OPTS="defaults,noatime,compress=zstd,subvol=@"
{
    echo "# <fs>                                  <mp>       <type>    <opts>               <d> <p>"
    echo "UUID=${ROOT_UUID}  /          ${FS_TYPE}  ${ROOT_OPTS}  0 1"
    echo "UUID=${EFI_UUID}   /boot/efi  vfat        defaults,noatime                        0 2"
    if [[ -n "$PART_SWAP" ]]; then
        SWAP_UUID=$(blkid -s UUID -o value "$PART_SWAP")
        echo "UUID=${SWAP_UUID}  none       swap        sw                                      0 0"
    fi
} > /mnt/gentoo/etc/fstab
success "fstab written."

# ── Mount pseudo-filesystems ──────────────────────────────────────────────────
header "Mounting pseudo-filesystems"
mount --types proc  /proc /mnt/gentoo/proc
mount --rbind       /sys  /mnt/gentoo/sys
mount --make-rslave       /mnt/gentoo/sys
mount --rbind       /dev  /mnt/gentoo/dev
mount --make-rslave       /mnt/gentoo/dev
mount --bind        /run  /mnt/gentoo/run 2>/dev/null || true

# ── Chroot stage ──────────────────────────────────────────────────────────────
header "Entering chroot"

# Resolve desktop packages — expanded into the heredoc before chroot runs
case "$DE_CHOICE" in
    2) DE_PKGS="gui-wm/hyprland gui-apps/hyprpaper gui-apps/hyprlock \
                gui-apps/waybar gui-apps/fuzzel gui-apps/swaylock \
                gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard \
                x11-misc/dunst sys-power/brightnessctl media-sound/pavucontrol \
                gnome-extra/polkit-gnome gui-apps/qt6ct \
                gui-libs/xdg-desktop-portal-hyprland \
                sys-apps/xdg-desktop-portal-gtk \
                media-fonts/nerdfonts www-client/brave-bin" ;;
    3) DE_PKGS="gui-wm/niri gui-apps/swaybg gui-apps/swaylock \
                gui-apps/waybar gui-apps/fuzzel \
                x11-misc/dunst app-misc/brightnessctl media-sound/pavucontrol \
                sys-apps/xdg-desktop-portal-gtk \
                media-fonts/nerdfonts www-client/brave-bin" ;;
    4) DE_PKGS="x11-wm/i3 x11-misc/polybar x11-misc/rofi x11-misc/picom \
                x11-misc/dunst x11-misc/i3lock x11-misc/xss-lock \
                x11-apps/xrandr x11-apps/xsetroot x11-apps/setxkbmap \
                x11-base/xorg-server media-gfx/maim x11-misc/xclip \
                sys-power/brightnessctl media-sound/pavucontrol \
                x11-themes/papirus-icon-theme \
                media-fonts/nerdfonts www-client/brave-bin" ;;
    *) DE_PKGS="" ;;
esac

# All DE choices need guru (nerd-fonts + brave-bin live there; Hyprland/niri too)
case "$DE_CHOICE" in
    2|3|4) NEED_GURU=1 ;;
    *)     NEED_GURU=0 ;;
esac

chroot /mnt/gentoo /bin/bash -euo pipefail << CHROOT
source /etc/profile
export PS1="(chroot) \$PS1"

# Redefine colours inside chroot (outer variables don't carry across)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "\${GREEN}ok\${NC}  \$*"; }
info() { echo -e "\${BLUE}::\${NC} \$*"; }

# ── Portage sync ──────────────────────────────────────────────────────────────
emerge-webrsync
eselect profile set default/linux/amd64/23.0

# ── Timezone ──────────────────────────────────────────────────────────────────
echo "${TIMEZONE}" > /etc/timezone
emerge --config sys-libs/timezone-data
ok "Timezone set."

# ── Locale ────────────────────────────────────────────────────────────────────
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile
ok "Locale set."

# ── Kernel ────────────────────────────────────────────────────────────────────
emerge sys-kernel/linux-firmware sys-firmware/intel-microcode
emerge sys-kernel/gentoo-sources
eselect kernel set 1
emerge sys-kernel/genkernel

if [[ -f /tmp/kernel-mba.config ]]; then
    cp /tmp/kernel-mba.config /usr/src/linux/.config
    genkernel --kernel-config=/usr/src/linux/.config all
else
    genkernel --menuconfig=no all
fi
ok "Kernel built."

# ── Overlays ──────────────────────────────────────────────────────────────────
if [[ "${NEED_GURU}" -eq 1 ]]; then
    emerge app-eselect/eselect-repository dev-vcs/git

    # guru: nerdfonts, brightnessctl, hyprland, niri
    eselect repository enable guru
    emaint sync --repo guru
    ok "guru overlay ready."

    # gentoo-zh: brave-bin
    eselect repository add gentoo-zh git https://github.com/microcai/gentoo-zh.git
    emaint sync --repo gentoo-zh
    ok "gentoo-zh overlay ready."

    # hyproverlay: xdg-desktop-portal-hyprland (Hyprland only)
    if [[ "${DE_CHOICE}" == "2" ]]; then
        eselect repository add hyproverlay git https://codeberg.org/hyproverlay/hyproverlay.git
        emaint sync --repo hyproverlay
        ok "hyproverlay ready."
    fi
fi

# ── Base system packages ───────────────────────────────────────────────────────
emerge \
    sys-apps/pciutils \
    sys-apps/usbutils \
    net-misc/networkmanager \
    net-wireless/wpa_supplicant \
    net-wireless/broadcom-sta \
    app-admin/sudo \
    sys-apps/dbus \
    sys-auth/polkit \
    sys-apps/acpi \
    app-laptop/laptop-mode-tools \
    sys-power/tlp \
    sys-apps/lm-sensors \
    app-misc/fastfetch \
    app-shells/zsh \
    dev-vcs/git \
    app-editors/neovim \
    media-video/pipewire \
    media-video/wireplumber \
    x11-terms/alacritty
ok "Base packages installed."

# ── Desktop environment ────────────────────────────────────────────────────────
if [[ -n "${DE_PKGS}" ]]; then
    # Install only JetBrains Mono from nerd-fonts — the full set is several GB
    mkdir -p /etc/portage/package.use
    echo "media-fonts/nerdfonts jetbrainsmono" > /etc/portage/package.use/nerdfonts
    emerge ${DE_PKGS}
    ok "Desktop environment installed."
fi

# ── GRUB (EFI) ────────────────────────────────────────────────────────────────
emerge sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Gentoo
grub-mkconfig -o /boot/grub/grub.cfg
ok "GRUB installed."

# ── Hostname ──────────────────────────────────────────────────────────────────
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF
ok "Hostname set."

# ── Services (OpenRC) ─────────────────────────────────────────────────────────
rc-update add NetworkManager  default
rc-update add bluetooth       default
rc-update add tlp             default
rc-update add laptop_mode     default
rc-update add dbus            default
rc-update add acpid           default
ok "Services enabled."

# ── Broadcom wl driver ────────────────────────────────────────────────────────
# Blacklist competing in-kernel drivers
cat > /etc/modprobe.d/broadcom-sta.conf << 'EOF'
blacklist brcmfmac
blacklist brcmsmac
blacklist b43
blacklist b43legacy
blacklist ssb
blacklist bcma
EOF
# Load wl at boot
echo "wl" > /etc/modules-load.d/broadcom-sta.conf
depmod -a
ok "Broadcom wl driver configured."

# ── Apple keyboard fn-mode ────────────────────────────────────────────────────
echo "options hid_apple fnmode=2" > /etc/modprobe.d/hid_apple.conf
ok "Apple fn-mode set."

# ── Backlight ─────────────────────────────────────────────────────────────────
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/90-backlight.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF
ok "Backlight udev rule written."

# ── sudo ──────────────────────────────────────────────────────────────────────
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# ── User ──────────────────────────────────────────────────────────────────────
groupadd -f plugdev
useradd -m -G wheel,audio,video,usb,plugdev,bluetooth -s /bin/zsh "${USERNAME}"
echo "Set password for ${USERNAME}:"
passwd "${USERNAME}"
echo "Set root password:"
passwd
ok "Users created."

# ── Dotfiles ──────────────────────────────────────────────────────────────────
if [[ "${WANT_DOTS}" =~ ^[Yy]\$ ]]; then
    su - "${USERNAME}" -c "git clone https://github.com/legendarymsr/legenddots ~/legenddots"
    su - "${USERNAME}" -c "mkdir -p ~/Pictures/Screenshots"

    # Common to all DEs
    su - "${USERNAME}" -c "
        mkdir -p ~/.config/alacritty
        ln -sfn ~/legenddots/alacritty.toml ~/.config/alacritty/alacritty.toml
        ln -sfn ~/legenddots/.zshrc ~/.zshrc
    "

    case "${DE_CHOICE}" in
        2)
            su - "${USERNAME}" -c "
                mkdir -p ~/.config/hypr
                ln -sfn ~/legenddots/hyprland/hyprland.conf  ~/.config/hypr/hyprland.conf
                ln -sfn ~/legenddots/hyprland/hyprpaper.conf ~/.config/hypr/hyprpaper.conf
                ln -sfn ~/legenddots/hyprland/hyprlock.conf  ~/.config/hypr/hyprlock.conf
                ln -sfn ~/legenddots/hyprland/waybar         ~/.config/waybar
            "
            ;;
        3)
            su - "${USERNAME}" -c "
                mkdir -p ~/.config/niri
                ln -sfn ~/legenddots/niri/config.kdl ~/.config/niri/config.kdl
                ln -sfn ~/legenddots/niri/waybar     ~/.config/waybar
                ln -sfn ~/legenddots/niri/fuzzel     ~/.config/fuzzel
                ln -sfn ~/legenddots/niri/dunst      ~/.config/dunst
                ln -sfn ~/legenddots/niri/swaylock   ~/.config/swaylock
            "
            ;;
        4)
            su - "${USERNAME}" -c "
                mkdir -p ~/.config/i3 ~/.config/picom ~/.config/rofi ~/.config/dunst
                ln -sfn ~/legenddots/i3/config           ~/.config/i3/config
                ln -sfn ~/legenddots/i3/picom.conf       ~/.config/picom/picom.conf
                ln -sfn ~/legenddots/i3/polybar          ~/.config/polybar
                ln -sfn ~/legenddots/i3/rofi/config.rasi ~/.config/rofi/config.rasi
                ln -sfn ~/legenddots/i3/dunst/dunstrc    ~/.config/dunst/dunstrc
                chmod +x ~/legenddots/i3/polybar/launch.sh
            "
            ;;
    esac
    ok "Dotfiles linked."
fi

echo ""
echo -e "\${GREEN}Installation complete.\${NC}"
echo "Exit the chroot, unmount, and reboot:"
echo "  exit"
echo "  umount -R /mnt/gentoo"
echo "  reboot"
CHROOT
