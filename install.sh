#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
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

# ── Desktop choice ────────────────────────────────────────────────────────────
echo ""
echo "  Which desktop?"
echo "  1) niri   (Wayland)"
echo "  2) hyprland (Wayland)"
echo "  3) Both"
echo ""
read -rp "Choice [1]: " CHOICE
CHOICE="${CHOICE:-1}"

# ── Packages ──────────────────────────────────────────────────────────────────
SHARED_PACMAN=(
    neovim
    emacs
    alacritty
    zsh
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
    pavucontrol
    brightnessctl
    dunst
    fuzzel
    ttf-jetbrains-mono-nerd
    xdg-desktop-portal-gtk
)

SHARED_AUR=(
    waybar-git
    brave-origin-nightly-bin
)

NIRI_PACMAN=(
    niri
    swaybg
    swaylock
)

HYPRLAND_PACMAN=(
    hyprland
    hyprpaper
    hyprlock
    wl-clipboard
    grim
    slurp
    polkit-gnome
    qt6ct
    xdg-desktop-portal-hyprland
)

info "Installing shared packages..."
sudo pacman -S --needed --noconfirm "${SHARED_PACMAN[@]}"
$AUR "${SHARED_AUR[@]}"

case "$CHOICE" in
    1)
        info "Installing niri packages..."
        sudo pacman -S --needed --noconfirm "${NIRI_PACMAN[@]}"
        ;;
    2)
        info "Installing hyprland packages..."
        sudo pacman -S --needed --noconfirm "${HYPRLAND_PACMAN[@]}"
        ;;
    3)
        info "Installing niri + hyprland packages..."
        sudo pacman -S --needed --noconfirm "${NIRI_PACMAN[@]}" "${HYPRLAND_PACMAN[@]}"
        ;;
    *) die "Invalid choice." ;;
esac

success "Packages installed."

# ── Symlink helper ────────────────────────────────────────────────────────────
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

# ── Shared symlinks ───────────────────────────────────────────────────────────
info "Linking shared configs..."
mkdir -p "$HOME/Pictures/Screenshots"

link "$REPO_DIR/.zshrc"              "$HOME/.zshrc"
link "$REPO_DIR/alacritty.toml"      "$HOME/.config/alacritty/alacritty.toml"
link "$REPO_DIR/init.lua"            "$HOME/.config/nvim/init.lua"
link "$REPO_DIR/init.el"             "$HOME/.config/emacs/init.el"

# ── Desktop symlinks ──────────────────────────────────────────────────────────
if [[ "$CHOICE" == "1" || "$CHOICE" == "3" ]]; then
    info "Linking niri configs..."
    link "$REPO_DIR/niri/config.kdl"   "$HOME/.config/niri/config.kdl"
    link "$REPO_DIR/niri/waybar"       "$HOME/.config/waybar"
    link "$REPO_DIR/niri/fuzzel"       "$HOME/.config/fuzzel"
    link "$REPO_DIR/niri/dunst"        "$HOME/.config/dunst"
    link "$REPO_DIR/niri/swaylock"     "$HOME/.config/swaylock"
fi

if [[ "$CHOICE" == "2" || "$CHOICE" == "3" ]]; then
    info "Linking hyprland configs..."
    link "$REPO_DIR/hyprland/hyprland.conf"  "$HOME/.config/hypr/hyprland.conf"
    link "$REPO_DIR/hyprland/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"
    link "$REPO_DIR/hyprland/hyprlock.conf"  "$HOME/.config/hypr/hyprlock.conf"
    link "$REPO_DIR/hyprland/waybar"         "$HOME/.config/waybar"
    link "$REPO_DIR/hyprland/fuzzel"         "$HOME/.config/fuzzel" 2>/dev/null || true
    link "$REPO_DIR/hyprland/dunst"          "$HOME/.config/dunst"  2>/dev/null || true
fi

# ── Pipewire ──────────────────────────────────────────────────────────────────
info "Enabling pipewire..."
systemctl --user enable --now pipewire.socket       2>/dev/null && success "pipewire enabled"       || warn "pipewire not found, skipping"
systemctl --user enable --now pipewire-pulse.socket 2>/dev/null && success "pipewire-pulse enabled" || warn "pipewire-pulse not found, skipping"
systemctl --user enable --now wireplumber.service   2>/dev/null && success "wireplumber enabled"    || warn "wireplumber not found, skipping"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Done.${NC}"
case "$CHOICE" in
    1) echo "Start niri: niri-session" ;;
    2) echo "Start hyprland: Hyprland" ;;
    3) echo "Start niri: niri-session  |  Start hyprland: Hyprland" ;;
esac
