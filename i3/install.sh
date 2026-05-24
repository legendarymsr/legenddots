#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}::${NC} $1"; }
success() { echo -e "${GREEN}ok${NC}  $1"; }
warn()    { echo -e "${YELLOW}warn${NC} $1"; }
die()     { echo -e "${RED}err${NC}  $1"; exit 1; }

if command -v paru &>/dev/null; then
    AUR="paru -S --needed --noconfirm"
elif command -v yay &>/dev/null; then
    AUR="yay -S --needed --noconfirm"
else
    die "No AUR helper found. Install paru or yay first."
fi

PACMAN_PKGS=(
    i3-wm
    polybar
    rofi
    picom
    alacritty
    dunst
    i3lock
    maim
    xclip
    xorg-xsetroot
    xorg-setxkbmap
    brightnessctl
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
    pavucontrol
    xss-lock
    papirus-icon-theme
    ttf-jetbrains-mono-nerd
)

AUR_PKGS=(
    brave-origin-nightly-bin
)

info "Installing packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
$AUR "${AUR_PKGS[@]}"
success "Packages installed."

link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Backing up $dst -> ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    success "Linked $dst"
}

info "Creating directories..."
mkdir -p "$HOME/Pictures/Screenshots"
success "Screenshots directory ready."

info "Linking configs..."
link "$REPO_DIR/config"             "$HOME/.config/i3/config"
link "$REPO_DIR/picom.conf"         "$HOME/.config/picom/picom.conf"
link "$REPO_DIR/polybar"            "$HOME/.config/polybar"
link "$REPO_DIR/rofi/config.rasi"   "$HOME/.config/rofi/config.rasi"
link "$REPO_DIR/dunst/dunstrc"      "$HOME/.config/dunst/dunstrc"
link "$REPO_DIR/../alacritty.toml"  "$HOME/.config/alacritty/alacritty.toml"

chmod +x "$HOME/.config/polybar/launch.sh"

info "Enabling pipewire..."
systemctl --user enable --now pipewire.socket       2>/dev/null && success "pipewire enabled"       || warn "pipewire not found, skipping"
systemctl --user enable --now pipewire-pulse.socket 2>/dev/null && success "pipewire-pulse enabled" || warn "pipewire-pulse not found, skipping"
systemctl --user enable --now wireplumber.service   2>/dev/null && success "wireplumber enabled"    || warn "wireplumber not found, skipping"

echo ""
echo -e "${GREEN}i3 rice installed.${NC}"
echo "Start i3 from your display manager or add 'exec i3' to ~/.xinitrc"
