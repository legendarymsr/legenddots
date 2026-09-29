#!/usr/bin/env bash
# =============================================================================
# Install doas + the legenddots bspwm rice on an ALREADY-INSTALLED Exherbo.
# The Exherbo counterpart of bspwm/install.sh (which covers Arch/KISS): deploys
# the real Tokyo Night configs, builds st from suckless/st/config.h, and pulls
# the stack with cave. Run as root.
#
#   doas ./setup-desktop.sh
#   TARGET_USER=legend KEYMAP=se ./setup-desktop.sh
#
# Env: TARGET_USER  whose ~ gets the configs (default: legend)
#      KEYMAP       override the setxkbmap line in bspwmrc (default: keep repo's 'se')
#      NO_DOAS=1 / NO_WM=1   skip either half
# =============================================================================
set -eu
SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO="$(cd "$SELF_DIR/.." && pwd)"

YEL='\033[0;33m'; CYAN='\033[0;36m'; GRN='\033[0;32m'; NC='\033[0m'
header() { printf '\n%b── %s %b\n' "$CYAN" "$*" "$NC"; }
warn()   { printf '%b! %s%b\n' "$YEL" "$*" "$NC"; }
[ "$(id -u)" -eq 0 ] || { printf 'run as root (doas ./setup-desktop.sh)\n' >&2; exit 1; }
source /etc/profile 2>/dev/null || true

RESOLVE="cave resolve -x --continue-on-failure if-independent"
dl_file() { if command -v curl >/dev/null 2>&1; then curl -fL# -o "$2" "$1"; else wget -O "$2" "$1"; fi; }

TARGET_USER="${TARGET_USER:-legend}"
KEYMAP="${KEYMAP:-}"
UH="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# ── doas ──────────────────────────────────────────────────────────────────────
if [ "${NO_DOAS:-}" != "1" ]; then
  header "Installing doas"
  if ! command -v doas >/dev/null 2>&1; then
    $RESOLVE repository/somasis 2>/dev/null && cave sync somasis 2>/dev/null || true
    if ! { $RESOLVE app-admin/doas 2>/dev/null && command -v doas >/dev/null 2>&1; }; then
      warn "somasis/doas unavailable — building doas from source (slicer69/doas)"
      ( cd /usr/src && rm -rf doas-master doas.tgz \
        && dl_file "https://codeload.github.com/slicer69/doas/tar.gz/refs/heads/master" doas.tgz \
        && tar xf doas.tgz && cd doas-master && make && make install ) \
        || warn "doas source build failed"
    fi
  fi
  if command -v doas >/dev/null 2>&1; then
    echo "permit persist :wheel" > /etc/doas.conf && chmod 0400 /etc/doas.conf
    printf '%bdoas ready (permit persist :wheel).%b\n' "$GRN" "$NC"
  fi
fi

# ── bspwm rice ────────────────────────────────────────────────────────────────
if [ "${NO_WM:-}" != "1" ]; then
  header "Installing Xorg + the bspwm rice (long compile)"
  # Core: Xorg, input, bspwm/sxhkd, and st's build deps.
  $RESOLVE xorg-server xinit xf86-input-libinput x11-libs/libX11 x11-libs/libXft \
           dev-util/pkgconf dev-scm/git bspwm sxhkd \
    || warn "core WM packages incomplete — check the cave output"
  # Rice extras — several may live in third-party repos and not resolve; that's
  # fine, bspwmrc backgrounds them so a missing one just doesn't launch.
  $RESOLVE picom dunst rofi dillo physlock polybar \
    || warn "some rice extras didn't resolve (bar/notifier/launcher/lock may be absent)"

  if [ -z "$UH" ] || [ ! -d "$UH" ]; then
    warn "no home dir for '$TARGET_USER' — set TARGET_USER= and re-run to drop configs"
  else
    # ── st, built from your suckless config.h (Tokyo Night) ──
    header "Building st from suckless/st/config.h"
    SRC="$UH/.local/src/st"
    mkdir -p "$(dirname "$SRC")"
    [ -d "$SRC/.git" ] || git clone https://git.suckless.org/st "$SRC" 2>/dev/null \
      || warn "st clone failed — build it by hand from suckless/st/config.h"
    if [ -d "$SRC" ] && [ -f "$REPO/suckless/st/config.h" ]; then
      cp "$REPO/suckless/st/config.h" "$SRC/config.h"
      ( cd "$SRC" && make clean >/dev/null 2>&1 || true; make && make install ) \
        && printf '%bst installed (Tokyo Night).%b\n' "$GRN" "$NC" \
        || warn "st build failed (needs libX11/libXft/pkgconf) — super+Return needs st"
    fi

    # ── deploy the real configs ──
    header "Deploying the rice configs to ${UH}"
    mkdir -p "$UH/.config/bspwm" "$UH/.config/sxhkd" "$UH/.config/polybar" \
             "$UH/.config/picom" "$UH/.config/rofi" "$UH/.config/dunst" "$UH/.dillo"
    cp "$REPO/bspwm/bspwmrc"            "$UH/.config/bspwm/bspwmrc"    && chmod +x "$UH/.config/bspwm/bspwmrc"
    cp "$REPO/bspwm/sxhkdrc"            "$UH/.config/sxhkd/sxhkdrc"
    cp "$REPO/bspwm/polybar/config.ini" "$UH/.config/polybar/config.ini"
    cp "$REPO/bspwm/polybar/launch.sh"  "$UH/.config/polybar/launch.sh" && chmod +x "$UH/.config/polybar/launch.sh"
    cp "$REPO/bspwm/picom.conf"         "$UH/.config/picom/picom.conf"
    cp "$REPO/bspwm/rofi/config.rasi"   "$UH/.config/rofi/config.rasi"   2>/dev/null || true
    cp "$REPO/bspwm/dunst/dunstrc"      "$UH/.config/dunst/dunstrc"      2>/dev/null || true
    cp "$REPO/scripts/dillo/dillorc"    "$UH/.dillo/dillorc"             2>/dev/null || true
    cp "$REPO/scripts/dillo/cookiesrc"  "$UH/.dillo/cookiesrc"           2>/dev/null || true
    # Optional keymap override (bspwmrc already ships 'setxkbmap se').
    [ -n "$KEYMAP" ] && sed -i "s/^setxkbmap .*/setxkbmap $KEYMAP/" "$UH/.config/bspwm/bspwmrc"
    printf 'exec bspwm\n' > "$UH/.xinitrc"

    # ── JetBrains Mono Nerd Font (polybar's font — best effort) ──
    FD="$UH/.local/share/fonts"; mkdir -p "$FD"
    if command -v unzip >/dev/null 2>&1; then
      dl_file "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" /tmp/jbm.zip 2>/dev/null \
        && unzip -oq /tmp/jbm.zip -d "$FD" 2>/dev/null \
        && { command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true; } \
        && printf '%bJetBrainsMono Nerd Font installed.%b\n' "$GRN" "$NC" \
        || warn "nerd font fetch failed — polybar falls back to a default font"
    else
      warn "unzip missing — skipping the nerd font (polybar uses a default font)"
    fi

    chown -R "$TARGET_USER:$TARGET_USER" "$UH/.config" "$UH/.xinitrc" "$UH/.dillo" "$UH/.local" 2>/dev/null || true
  fi

  # physlock must be setuid root to lock every VT.
  for p in /usr/bin/physlock /usr/local/bin/physlock; do
    [ -x "$p" ] && chmod u+s "$p" 2>/dev/null && printf 'physlock setuid: %s\n' "$p" || true
  done
fi

header "setup-desktop complete"
printf 'As %s: %bstartx%b   (super+Return = st · super+p = rofi · super+w = dillo · super+shift+x = lock)\n' \
  "$TARGET_USER" "$GRN" "$NC"
