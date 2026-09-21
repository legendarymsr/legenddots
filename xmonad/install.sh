#!/usr/bin/env bash
# Minimal XMonad + ly setup (Arch). Installs the pieces, links the configs,
# points ly at an XMonad session. Everything here is in the official repos.
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}::${NC} $1"; }
success() { echo -e "${GREEN}ok${NC}  $1"; }
warn()    { echo -e "${YELLOW}warn${NC} $1"; }

PKGS=(
    xmonad xmonad-contrib xmobar   # WM + simple bar
    picom rofi dunst alacritty     # compositor, launcher, notifications, terminal
    ly                             # display manager
    physlock                       # TTY-style screen lock
    xorg-server xorg-xinit
    ttf-jetbrains-mono-nerd
)

info "Installing packages..."
sudo pacman -S --needed --noconfirm "${PKGS[@]}"
success "Packages installed."

link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Backing up $dst -> ${dst}.bak"; mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    success "Linked $dst"
}

info "Linking configs..."
link "$REPO_DIR/xmonad.hs"        "$HOME/.config/xmonad/xmonad.hs"
link "$REPO_DIR/xmobarrc"         "$HOME/.xmobarrc"
link "$REPO_DIR/picom.conf"       "$HOME/.config/picom/picom.conf"
link "$REPO_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
link "$REPO_DIR/dunst/dunstrc"    "$HOME/.config/dunst/dunstrc"

info "Installing the ly config and the XMonad session..."
[[ -e /etc/ly/config.ini && ! -L /etc/ly/config.ini ]] && sudo cp -n /etc/ly/config.ini /etc/ly/config.ini.bak || true
sudo install -Dm644 "$REPO_DIR/ly/config.ini"    /etc/ly/config.ini
sudo install -Dm644 "$REPO_DIR/xmonad.desktop"   /usr/share/xsessions/xmonad.desktop

info "Making physlock runnable from a keybind (setuid root)..."
sudo chmod u+s /usr/bin/physlock 2>/dev/null && success "physlock setuid" || warn "physlock not found — set it up by hand"

info "Compiling xmonad..."
if command -v xmonad &>/dev/null; then
    xmonad --recompile && success "xmonad compiled" || warn "recompile failed — check ~/.config/xmonad/xmonad.hs"
fi

info "Enabling ly (disabling any other display manager)..."
sudo systemctl disable display-manager.service 2>/dev/null || true
sudo systemctl enable ly.service && success "ly enabled" || warn "could not enable ly.service"

echo ""
echo -e "${GREEN}Minimal XMonad + ly installed.${NC} Reboot, pick XMonad at the ly login."
echo "Keys: Mod(Super)+Return = alacritty · Mod+p = rofi · Mod+Space = layout · Mod+b = toggle bar · Mod+Shift+l = lock · Mod+q = reload"
