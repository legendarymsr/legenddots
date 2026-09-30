#!/bin/sh
# =============================================================================
# alpine/setup.sh — minimal Alpine riscv64 desktop for the StarFive VisionFive 2
# (or any Alpine box): bspwm + xterm + vis + lynx.
#
# EVERYTHING is a binary apk package — ZERO compilation. suckless's config.h
# "just recompile" model is misery on a 1.5 GHz U74, so the terminal is themed
# via ~/.Xresources, the WM via runtime ~/.config, and vis via Lua. No source
# builds, no GPU/compositor (the VF2's GPU driver is a mess and unneeded here).
#
# Run as root on a booted Alpine, AFTER the base install (see README.md):
#   TARGET_USER=legend KEYMAP=se ./setup.sh
#
# Env: TARGET_USER  who gets the desktop (default: legend)
#      KEYMAP       X keyboard layout (default: us)
# =============================================================================
set -eu
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SELF_DIR/.." && pwd)"
GRN='\033[0;32m'; YEL='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
say()  { printf '%b:: %s%b\n' "$CYAN" "$*" "$NC"; }
warn() { printf '%b!! %s%b\n' "$YEL" "$*" "$NC"; }
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }

TARGET_USER="${TARGET_USER:-legend}"
KEYMAP="${KEYMAP:-us}"

# ── enable the community repo (bspwm, sxhkd, vis, dmenu live there) ───────────
if ! grep -qE '^[^#].*/community$' /etc/apk/repositories 2>/dev/null; then
  say "enabling the community repository"
  sed -i -E 's|^#(\s*https?://.*/community)$|\1|' /etc/apk/repositories || true
fi
apk update

# ── install the desktop — all binary, no compilation ─────────────────────────
say "installing Xorg + bspwm + xterm + vis + lynx (binary packages)"
apk add \
  xorg-server xinit xf86-input-libinput xf86-video-fbdev \
  xrdb setxkbmap xsetroot \
  bspwm sxhkd dmenu xterm \
  vis lynx \
  || warn "core install had issues — check the apk output above"
# fonts are best-effort (name varies); xterm falls back to a default otherwise
apk add font-jetbrains-mono-nerd 2>/dev/null \
  || apk add ttf-jetbrains-mono 2>/dev/null \
  || apk add font-terminus 2>/dev/null \
  || warn "no JetBrains/Terminus font found — xterm uses a default"

# ── user ─────────────────────────────────────────────────────────────────────
if ! id "$TARGET_USER" >/dev/null 2>&1; then
  say "creating user $TARGET_USER"
  adduser -D "$TARGET_USER"
  for g in input video audio wheel; do addgroup "$TARGET_USER" "$g" 2>/dev/null || true; done
  passwd "$TARGET_USER"
fi
UH="$(awk -F: -v u="$TARGET_USER" '$1==u{print $6}' /etc/passwd)"
[ -n "$UH" ] && [ -d "$UH" ] || { warn "no home dir for $TARGET_USER"; exit 1; }

# ── dotfiles (all runtime — nothing compiled) ────────────────────────────────
say "writing dotfiles into $UH"
mkdir -p "$UH/.config/bspwm" "$UH/.config/sxhkd" "$UH/.config/vis/themes"

# bspwmrc — minimal: no compositor (software rendering on the VF2), just bspwm.
cat > "$UH/.config/bspwm/bspwmrc" <<BSPWM
#!/bin/sh
sxhkd &
setxkbmap ${KEYMAP}
xsetroot -solid '#1a1b26'

bspc monitor -d 1 2 3 4 5
bspc config border_width          2
bspc config window_gap            6
bspc config normal_border_color   "#1a1b26"
bspc config focused_border_color  "#7aa2f7"
bspc config focus_follows_pointer true
BSPWM
chmod +x "$UH/.config/bspwm/bspwmrc"

# sxhkdrc — xterm terminal, dmenu launcher (themed by flags, not a rebuild),
# lynx + vis in a terminal.
cat > "$UH/.config/sxhkd/sxhkdrc" <<'SXHKD'
super + Return
	xterm
super + p
	dmenu_run -nb '#1a1b26' -nf '#c0caf5' -sb '#7aa2f7' -sf '#1a1b26'
super + w
	xterm -e lynx
super + e
	xterm -e vis
super + {_,shift + }q
	bspc node -{c,k}
super + {1-5}
	bspc desktop -f '^{1-5}'
super + shift + {1-5}
	bspc node -d '^{1-5}'
super + {h,j,k,l}
	bspc node -f {west,south,north,east}
super + {t,f}
	bspc node -t {tiled,fullscreen}
super + shift + r
	bspc wm -r
super + shift + Escape
	bspc quit
super + Escape
	pkill -USR1 -x sxhkd
SXHKD

# xterm theme (Tokyo Night) — st's config.h moved to a runtime Xresources file.
cp "$SELF_DIR/Xresources" "$UH/.Xresources"

# vis: reuse the repo's config + Tokyo Night theme (name-based, works everywhere).
cp "$REPO/suckless/vis/visrc.lua"             "$UH/.config/vis/visrc.lua"
cp "$REPO/suckless/vis/themes/tokyonight.lua" "$UH/.config/vis/themes/tokyonight.lua"
# vis only searches its INSTALL theme dir — drop the theme there too.
VISBIN="$(command -v vis 2>/dev/null || true)"
if [ -n "$VISBIN" ]; then
  VISTHEMES="$(cd "$(dirname "$VISBIN")/../share/vis/themes" 2>/dev/null && pwd || true)"
  [ -n "$VISTHEMES" ] && cp "$REPO/suckless/vis/themes/tokyonight.lua" "$VISTHEMES/tokyonight.lua" 2>/dev/null || true
fi

# busybox vi reads $EXINIT (not ~/.exrc) — give it the baseline for the recovery vi.
grep -q 'EXINIT' "$UH/.profile" 2>/dev/null || \
  echo "export EXINIT='set autoindent shiftwidth=4 tabstop=4 showmatch number'" >> "$UH/.profile"

# .xinitrc — load Xresources, then bspwm.
cat > "$UH/.xinitrc" <<'XINIT'
#!/bin/sh
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
exec bspwm
XINIT

chown -R "$TARGET_USER:$TARGET_USER" \
  "$UH/.config" "$UH/.Xresources" "$UH/.xinitrc" "$UH/.profile" 2>/dev/null || true

say "done"
printf '%bLog in as %s, then: startx%b\n' "$GRN" "$TARGET_USER" "$NC"
printf 'Keys: super+Return xterm · super+p dmenu · super+w lynx · super+e vis · super+{h,j,k,l} focus · super+shift+Esc quit\n'
