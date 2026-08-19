#!/usr/bin/env bash
# Apply the desktop wallpaper with swaybg. Idempotent: kills any running swaybg
# first, so it's safe to run at niri startup (spawn-at-startup) or by hand.
#
# niri's spawn-at-startup runs commands WITHOUT a shell, so a bare "~" in the
# path is never expanded — that's why setting swaybg directly from config.kdl
# silently failed. Running it through this script (via `sh -c`) fixes that.
set -u

WALLPAPER="${WALLPAPER:-$HOME/.config/wallpapers/6orjlq.jpg}"
MODE="${WALLPAPER_MODE:-fill}"

if [ ! -f "$WALLPAPER" ]; then
  echo "wallpaper: not found: $WALLPAPER" >&2
  exit 1
fi

# Replace any existing swaybg so re-running doesn't stack instances.
pkill -x swaybg 2>/dev/null
exec swaybg -m "$MODE" -i "$WALLPAPER"
