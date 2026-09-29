#!/usr/bin/env bash
# =============================================================================
# Install doas + a bspwm desktop on an ALREADY-INSTALLED Exherbo. Run as root
# (the installer does this at install time via INSTALL_WM=yes; this is the same
# thing for a system that's already up).
#
#   doas ./setup-desktop.sh                       # or run as root
#   TARGET_USER=legend KEYMAP=se ./setup-desktop.sh
#
# Env: TARGET_USER  whose ~ gets the WM config (default: legend)
#      KEYMAP       X keyboard layout for setxkbmap in .xinitrc (default: us)
#      NO_DOAS=1    skip the doas step (just the WM)
#      NO_WM=1      skip the WM step (just doas)
# =============================================================================
set -eu
YEL='\033[0;33m'; CYAN='\033[0;36m'; GRN='\033[0;32m'; NC='\033[0m'
header() { printf '\n%b── %s %b\n' "$CYAN" "$*" "$NC"; }
warn()   { printf '%b! %s%b\n' "$YEL" "$*" "$NC"; }
[ "$(id -u)" -eq 0 ] || { printf 'run as root (doas ./setup-desktop.sh)\n' >&2; exit 1; }
source /etc/profile 2>/dev/null || true

RESOLVE="cave resolve -x --continue-on-failure if-independent"
dl_file() { if command -v curl >/dev/null 2>&1; then curl -fL# -o "$2" "$1"; else wget -O "$2" "$1"; fi; }

TARGET_USER="${TARGET_USER:-legend}"
KEYMAP="${KEYMAP:-us}"

# ── doas ──────────────────────────────────────────────────────────────────────
if [ "${NO_DOAS:-}" != "1" ]; then
  header "Installing doas"
  if ! command -v doas >/dev/null 2>&1; then
    # doas isn't in arbor — try the third-party 'somasis' repo, else source-build.
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
  else
    warn "doas still not installed"
  fi
fi

# ── bspwm desktop ─────────────────────────────────────────────────────────────
if [ "${NO_WM:-}" != "1" ]; then
  header "Installing the bspwm desktop (Xorg + bspwm — long compile)"
  $RESOLVE xorg-server xinit xf86-input-libinput bspwm sxhkd xterm \
    || warn "some WM packages didn't resolve — finish by hand with cave"

  UH="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  if [ -n "$UH" ] && [ -d "$UH" ]; then
    mkdir -p "$UH/.config/bspwm" "$UH/.config/sxhkd"
    cat > "$UH/.config/bspwm/bspwmrc" <<'BSPWM'
#!/bin/sh
bspc monitor -d 1 2 3 4 5
bspc config border_width          2
bspc config window_gap            8
bspc config focus_follows_pointer true
BSPWM
    chmod +x "$UH/.config/bspwm/bspwmrc"
    cat > "$UH/.config/sxhkd/sxhkdrc" <<'SXHKD'
super + Return
	xterm
super + w
	bspc node -c
super + {1-5}
	bspc desktop -f '^{1-5}'
super + shift + q
	bspc quit
SXHKD
    printf 'sxhkd &\nsetxkbmap %s &\nexec bspwm\n' "$KEYMAP" > "$UH/.xinitrc"
    chown -R "$TARGET_USER:$TARGET_USER" "$UH/.config" "$UH/.xinitrc" 2>/dev/null || true
    printf '%bDesktop ready — log in as %s and run: startx  (super+Return = terminal)%b\n' "$GRN" "$TARGET_USER" "$NC"
  else
    warn "no home dir for '$TARGET_USER' — set TARGET_USER= and re-run to drop the config"
  fi
fi

header "setup-desktop complete"
