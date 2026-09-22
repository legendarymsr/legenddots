#!/usr/bin/env bash
# Minimal XMonad + ly setup. Works on:
#   - Arch  (pacman; ly enabled via systemd)
#   - KISS  (kiss + ghcup for GHC; started with startx)
# Links the configs, installs the ly config + XMonad session, sets physlock
# setuid for the TTY lock.
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
    link "$REPO_DIR/xmonad.hs"        "$HOME/.config/xmonad/xmonad.hs"
    link "$REPO_DIR/xmobarrc"         "$HOME/.xmobarrc"
    link "$REPO_DIR/picom.conf"       "$HOME/.config/picom/picom.conf"
    link "$REPO_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
    link "$REPO_DIR/dunst/dunstrc"    "$HOME/.config/dunst/dunstrc"
    # Dillo reads its config ONLY from ~/.dillo/ (no XDG). Link the repo's copy.
    link "$REPO_DIR/../scripts/dillo/dillorc"   "$HOME/.dillo/dillorc"
    link "$REPO_DIR/../scripts/dillo/cookiesrc" "$HOME/.dillo/cookiesrc"

    info "Installing the ly config and the XMonad session..."
    [[ -e /etc/ly/config.ini && ! -L /etc/ly/config.ini ]] && $SUDO cp -n /etc/ly/config.ini /etc/ly/config.ini.bak || true
    $SUDO install -Dm644 "$REPO_DIR/ly/config.ini"  /etc/ly/config.ini
    $SUDO install -Dm644 "$REPO_DIR/xmonad.desktop" /usr/share/xsessions/xmonad.desktop
}

finish() {
    if [[ -x /usr/bin/physlock ]]; then
        $SUDO chmod u+s /usr/bin/physlock && success "physlock setuid" || warn "couldn't setuid physlock"
    else
        warn "physlock not installed — the Mod-Shift-l lock won't work until it is"
    fi
    if command -v xmonad &>/dev/null; then
        xmonad --recompile && success "xmonad compiled" || warn "recompile failed — check ~/.config/xmonad/xmonad.hs"
    else
        warn "xmonad not on PATH yet — recompile once it is"
    fi
}

# ── Arch ──────────────────────────────────────────────────────────────────────
install_arch() {
    local PKGS=(
        xmonad xmonad-contrib xmobar
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
    echo -e "${GREEN}XMonad + ly installed (Arch).${NC} Reboot, pick XMonad at the ly login."
}

# ── KISS ──────────────────────────────────────────────────────────────────────
install_kiss() {
    export KISS_PROMPT=0
    info "Building packages (kiss)... (names can vary by repo revision)"
    for pkg in xorg-server xinit xsetroot \
               libx11 libxext libxft libxinerama libxrandr libxss \
               alacritty rofi picom dunst physlock dillo ttf-dejavu ly; do
        if kiss build "$pkg" && kiss install "$pkg"; then success "$pkg"
        else warn "$pkg not in KISS_PATH — build it by hand later"; fi
    done

    # KISS ships no ghc in core/extra: bootstrap the Haskell toolchain with ghcup
    # (the one heavy dep) and build xmonad from Hackage with cabal.
    if ! command -v xmonad &>/dev/null; then
        info "Bootstrapping GHC + cabal via ghcup, then building xmonad..."
        export BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_MINIMAL=1
        curl -fsSL https://get-ghcup.haskell.org | sh || warn "ghcup failed — install GHC/cabal by hand"
        [ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"
        ghcup install ghc   --set recommended || true
        ghcup install cabal --set recommended || true
        cabal update || true
        cabal install --lib xmonad xmonad-contrib || true
        cabal install xmonad || true
        cabal install xmobar || true
        export PATH="$HOME/.cabal/bin:$PATH"
    fi

    deploy_configs
    finish

    # ly's service depends on your init (KISS isn't systemd), so wire up startx
    # as the reliable path and leave enabling ly to you.
    cat > "$HOME/.xinitrc" <<'EOF'
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"
export PATH="$HOME/.cabal/bin:$HOME/.local/bin:$PATH"
exec xmonad
EOF
    echo ""
    echo -e "${GREEN}XMonad installed (KISS).${NC} Run 'startx' to launch it."
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

echo "Keys: Mod(Super)+Return = alacritty · Mod+p = rofi · Mod+w = dillo · Mod+Space = layout · Mod+b = toggle bar · Mod+Shift+l = lock · Mod+q = reload"
