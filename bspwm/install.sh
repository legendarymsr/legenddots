#!/usr/bin/env bash
# Minimal bspwm setup. Works on:
#   - Arch  (pacman; ly enabled via systemd)
#   - KISS  (kiss; started with startx)
# Everything here is plain C — no Haskell/Rust toolchain to bootstrap. Links the
# configs, installs the ly config + bspwm session, sets physlock setuid.
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${BLUE}::${NC} $1"; }
success() { echo -e "${GREEN}ok${NC}  $1"; }
warn()    { echo -e "${YELLOW}warn${NC} $1"; }
die()     { echo -e "${RED}err${NC}  $1"; exit 1; }

# doas first (the legenddots way), then sudo, else assume root.
if command -v doas &>/dev/null; then SUDO="doas"
elif command -v sudo &>/dev/null; then SUDO="sudo"
else SUDO=""; fi

link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Backing up $dst -> ${dst}.bak"; mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    success "Linked $dst"
}

deploy_configs() {
    info "Linking configs..."
    link "$REPO_DIR/bspwmrc"            "$HOME/.config/bspwm/bspwmrc"
    link "$REPO_DIR/sxhkdrc"            "$HOME/.config/sxhkd/sxhkdrc"
    link "$REPO_DIR/polybar/config.ini" "$HOME/.config/polybar/config.ini"
    link "$REPO_DIR/polybar/launch.sh"  "$HOME/.config/polybar/launch.sh"
    link "$REPO_DIR/picom.conf"         "$HOME/.config/picom/picom.conf"
    link "$REPO_DIR/rofi/config.rasi"   "$HOME/.config/rofi/config.rasi"
    link "$REPO_DIR/dunst/dunstrc"      "$HOME/.config/dunst/dunstrc"
    # Dillo reads its config ONLY from ~/.dillo/ (no XDG). Link the repo's copy.
    link "$REPO_DIR/../scripts/dillo/dillorc"   "$HOME/.dillo/dillorc"
    link "$REPO_DIR/../scripts/dillo/cookiesrc" "$HOME/.dillo/cookiesrc"

    info "Installing the ly config and the bspwm session..."
    [[ -e /etc/ly/config.ini && ! -L /etc/ly/config.ini ]] && $SUDO cp -n /etc/ly/config.ini /etc/ly/config.ini.bak || true
    $SUDO install -Dm644 "$REPO_DIR/ly/config.ini"  /etc/ly/config.ini
    $SUDO install -Dm644 "$REPO_DIR/bspwm.desktop"  /usr/share/xsessions/bspwm.desktop
}

finish() {
    if [[ -x /usr/bin/physlock ]]; then
        $SUDO chmod u+s /usr/bin/physlock && success "physlock setuid" || warn "couldn't setuid physlock"
    else
        warn "physlock not installed — the super+shift+x lock won't work until it is"
    fi
}

# ── Arch ──────────────────────────────────────────────────────────────────────
install_arch() {
    local PKGS=(
        bspwm sxhkd polybar
        picom rofi dunst alacritty dillo
        ly physlock
        xorg-server xorg-xinit
        ttf-jetbrains-mono-nerd
    )
    info "Installing packages (pacman)..."
    $SUDO pacman -S --needed --noconfirm "${PKGS[@]}"
    deploy_configs
    finish
    info "Enabling ly (disabling any other display manager)..."
    $SUDO systemctl disable display-manager.service 2>/dev/null || true
    $SUDO systemctl enable ly.service && success "ly enabled" || warn "could not enable ly.service"
    echo ""
    echo -e "${GREEN}bspwm + ly installed (Arch).${NC} Reboot, pick bspwm at the ly login."
}

# ── KISS ──────────────────────────────────────────────────────────────────────
install_kiss() {
    export KISS_PROMPT=0
    info "Building packages (kiss)... (names can vary by repo revision)"
    for pkg in xorg-server xinit xsetroot \
               libx11 libxext libxft libxinerama libxrandr \
               bspwm sxhkd polybar picom rofi dunst physlock dillo alacritty \
               ttf-dejavu ly; do
        if kiss build "$pkg" && kiss install "$pkg"; then success "$pkg"
        else warn "$pkg not in KISS_PATH — build it by hand later"; fi
    done

    deploy_configs
    finish

    # ly's service depends on your init (KISS isn't systemd), so wire up startx
    # and leave enabling ly to you.
    cat > "$HOME/.xinitrc" <<'EOF'
exec bspwm
EOF
    echo ""
    echo -e "${GREEN}bspwm installed (KISS).${NC} Run 'startx' to launch it."
    echo "ly is built + its config is in place; enable it for your init (KISS isn't systemd)."
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
if command -v pacman &>/dev/null; then
    install_arch
elif command -v kiss &>/dev/null; then
    install_kiss
else
    die "no supported package manager found (need pacman for Arch or kiss for KISS)"
fi

echo "Keys: super+Return = alacritty · super+p = rofi · super+w = dillo · super+shift+x = lock · super+{h,j,k,l} = focus · super+alt+q = quit"
