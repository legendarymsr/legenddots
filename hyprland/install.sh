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
    hyprland
    hyprpaper
    hyprlock
    fuzzel
    alacritty
    dunst
    waybar
    grim
    slurp
    wl-clipboard
    brightnessctl
    wireplumber
    pavucontrol
    polkit-gnome
    qt6ct
    ttf-jetbrains-mono-nerd
    xdg-desktop-portal-hyprland
)

info "Installing packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
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

info "Linking configs..."
link "$REPO_DIR/hyprland.conf"  "$HOME/.config/hypr/hyprland.conf"
link "$REPO_DIR/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"
link "$REPO_DIR/hyprlock.conf"  "$HOME/.config/hypr/hyprlock.conf"
link "$REPO_DIR/waybar"         "$HOME/.config/waybar"

warn "No wallpaper set — add one at ~/.config/hyprland/wallpaper.jpg or edit hyprpaper.conf"

info "Enabling wireplumber..."
systemctl --user enable --now wireplumber.service 2>/dev/null && success "wireplumber enabled" || warn "wireplumber not found, skipping"

echo ""
echo -e "${GREEN}Hyprland rice installed.${NC}"
echo "Start with: Hyprland"
