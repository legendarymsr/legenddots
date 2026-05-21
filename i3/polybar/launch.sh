#!/usr/bin/env bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done
polybar --config="$HOME/.config/i3/polybar/config.ini" main 2>&1 | tee /tmp/polybar.log &
