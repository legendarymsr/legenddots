#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}::${NC} $1"; }
success() { echo -e "${GREEN}ok${NC}  $1"; }
warn()    { echo -e "${YELLOW}warn${NC} $1"; }
die()     { echo -e "${RED}err${NC}  $1"; exit 1; }

# ── AUR helper ────────────────────────────────────────────────────────────────
if command -v paru &>/dev/null; then
    AUR="paru -S --needed --noconfirm"
elif command -v yay &>/dev/null; then
    AUR="yay -S --needed --noconfirm"
else
    die "No AUR helper found. Install paru or yay first."
fi

# ── Packages ──────────────────────────────────────────────────────────────────
PACMAN_PKGS=(
    niri
    fuzzel
    swaybg
    swaylock
    dunst
    alacritty
    brightnessctl
    wireplumber
    pavucontrol
    ttf-jetbrains-mono-nerd
    xdg-desktop-portal-gnome
)

AUR_PKGS=(
    waybar-git
    brave-origin-nightly-bin
)

info "Installing pacman packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

info "Installing AUR packages..."
$AUR "${AUR_PKGS[@]}"

success "Packages installed."

# ── Config symlinks ───────────────────────────────────────────────────────────
link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Backing up existing $dst -> ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    success "Linked $dst"
}

info "Linking configs..."

link "$REPO_DIR/config.kdl"         "$HOME/.config/niri/config.kdl"
link "$REPO_DIR/waybar"             "$HOME/.config/waybar"
link "$REPO_DIR/fuzzel"             "$HOME/.config/fuzzel"
link "$REPO_DIR/dunst"              "$HOME/.config/dunst"
link "$REPO_DIR/swaylock"           "$HOME/.config/swaylock"

# ── systemd user services ─────────────────────────────────────────────────────
info "Enabling systemd user services..."
systemctl --user enable --now wireplumber.service 2>/dev/null && success "wireplumber enabled" || warn "wireplumber service not found, skipping"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Rice installed.${NC}"
echo "Start niri from a TTY: niri-session"
