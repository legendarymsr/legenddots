#!/usr/bin/env sh
# Restart polybar cleanly (bspwmrc runs this on start / restart).
killall -q polybar 2>/dev/null
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.5; done
polybar main &
