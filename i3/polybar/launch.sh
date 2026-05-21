#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done
polybar --config="$DIR/config.ini" main 2>&1 | tee /tmp/polybar.log &
