#!/usr/bin/env bash
# =============================================================================
# Install doas + a suckless desktop on an ALREADY-INSTALLED Exherbo: dwm (WM,
# built-in bar), dmenu (launcher), st (terminal), slock (lock), surf (browser) —
# all built from git.suckless.org with the config.h files in ../suckless/. No
# third-party package repos needed for the tools themselves (they're source
# builds); only Xorg + the X libraries come from cave. Run as root.
#
#   doas ./setup-desktop.sh
#   TARGET_USER=legend KEYMAP=se ./setup-desktop.sh
#
# Env: TARGET_USER  whose ~ gets the session (default: legend)
#      KEYMAP       X keyboard layout in .xinitrc (default: se)
#      NO_DOAS=1 / NO_WM=1   skip either half
#      NO_SURF=1    skip surf (its WebKit dep is a huge build)
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

# ── Enable the third-party repos this stuff lives in (NONE are in arbor) ───────
# bspwm/sxhkd/rofi/picom/dunst/doas/fastfetch all live in unofficial repos that
# must be added via the 'unavailable' meta-repos first. Best-effort: cave will
# still name anything that can't be found.
enable_repos() {
  header "Enabling third-party repos (the WM stack isn't in arbor)"
  cave sync 2>/dev/null || true
  for r in unavailable unavailable-unofficial; do
    cave resolve -x1 "repository/$r" 2>/dev/null || true
  done
  for r in x11 desktop hasufell somasis tombriden hardware; do
    cave resolve -x1 "repository/$r" 2>/dev/null || warn "repo '$r' not enabled — its packages will be unavailable"
  done
  cave sync 2>/dev/null || true
}
[ "${NO_REPOS:-}" = "1" ] || enable_repos

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

# ── suckless desktop: dwm + dmenu + st + slock + surf (built from source) ─────
if [ "${NO_WM:-}" != "1" ]; then
  header "Installing Xorg + the suckless build deps"
  # Xorg + the X libraries the suckless tools compile against. The tools
  # themselves are built from git.suckless.org below — no package repo needed.
  $RESOLVE xorg-server xinit xf86-input-libinput \
           x11-libs/libX11 x11-libs/libXft x11-libs/libXinerama x11-libs/libXext \
           media-libs/fontconfig media-libs/freetype dev-util/pkgconf dev-scm/git \
    || warn "some Xorg/X11 build deps didn't resolve — a suckless build may fail"
  # surf needs WebKit (a big build). Skip it with NO_SURF=1.
  if [ "${NO_SURF:-}" != "1" ]; then
    $RESOLVE webkit gtk+ || warn "webkit/gtk didn't resolve — surf won't build (NO_SURF=1 to skip)"
  fi

  if [ -z "$UH" ] || [ ! -d "$UH" ]; then
    warn "no home dir for '$TARGET_USER' — set TARGET_USER= and re-run"
  else
    # Build one suckless tool from git.suckless.org with your repo's config.h.
    build_sl() {
      t="$1"; SRC="$UH/.local/src/$t"
      mkdir -p "$(dirname "$SRC")"
      [ -d "$SRC/.git" ] || git clone "https://git.suckless.org/$t" "$SRC" 2>/dev/null \
        || { warn "$t: clone failed"; return 1; }
      # Symlink your repo's config.h in (not a copy), so editing
      # ../suckless/$t/config.h and rerunning rebuilds with the change.
      [ -f "$REPO/suckless/$t/config.h" ] && ln -sfn "$REPO/suckless/$t/config.h" "$SRC/config.h"
      ( cd "$SRC" && make clean >/dev/null 2>&1 || true; make && make install ) \
        && printf '%b%s installed%b\n' "$GRN" "$t" "$NC" || { warn "$t: build failed"; return 1; }
    }

    header "Building the suckless tools (dwm · dmenu · st · slock · surf)"
    build_sl dwm
    build_sl dmenu
    build_sl st
    build_sl slock
    [ "${NO_SURF:-}" = "1" ] || build_sl surf

    # ── session: dwm + a status loop feeding dwm's built-in bar ──
    header "Writing ~/.xinitrc (dwm + status bar)"
    cat > "$UH/.xinitrc" <<XINIT
#!/bin/sh
setxkbmap ${KEYMAP:-se}
# dwm's bar shows the root window name — feed it ram · battery · date.
while :; do
  ram=\$(free -m 2>/dev/null | awk '/Mem:/{printf "%d%%", (\$3/\$2)*100}')
  bat=\$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
  [ -n "\$bat" ] && bat=" · bat \${bat}%"
  xsetroot -name "ram \${ram}\${bat} · \$(date '+%a %d %b %H:%M')"
  sleep 3
done &
exec dwm
XINIT

    # ── JetBrains Mono Nerd Font (best effort) ──
    FD="$UH/.local/share/fonts"; mkdir -p "$FD"
    if command -v unzip >/dev/null 2>&1; then
      dl_file "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" /tmp/jbm.zip 2>/dev/null \
        && unzip -oq /tmp/jbm.zip -d "$FD" 2>/dev/null \
        && { command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true; } \
        && printf '%bJetBrainsMono Nerd Font installed.%b\n' "$GRN" "$NC" \
        || warn "nerd font fetch failed — dwm/st fall back to a default font"
    else
      warn "unzip missing — skipping the nerd font"
    fi

    chown -R "$TARGET_USER:$TARGET_USER" "$UH/.xinitrc" "$UH/.local" 2>/dev/null || true
  fi

  # slock must be setuid root to lock the screen and authenticate.
  for p in /usr/bin/slock /usr/local/bin/slock; do
    [ -x "$p" ] && chmod u+s "$p" 2>/dev/null && printf 'slock setuid: %s\n' "$p" || true
  done
fi

header "setup-desktop complete"
printf 'As %s: %bstartx%b   (Mod+Return = st · Mod+d = dmenu · Mod+b = surf · Mod+Escape = slock · Mod+shift+q = kill — keys in suckless/dwm/config.h)\n' \
  "$TARGET_USER" "$GRN" "$NC"
