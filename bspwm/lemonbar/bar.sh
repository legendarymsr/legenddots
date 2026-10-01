#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# ~/.config/lemonbar/bar.sh — legenddots Tokyo Night bar: ram · battery · date
# Pure shell + lemonbar (C). No Haskell, no polybar. bspwmrc launches this.
#
# NOTE: the font line needs a lemonbar built with Xft (the common `lemonbar-xft`
# fork). If your lemonbar is the plain core-font build, drop the `-f "$FONT"`.

BG="#1a1b26"; FG="#c0caf5"; AC="#7aa2f7"
FONT="JetBrainsMono Nerd Font:size=10"
P='%'   # literal percent for the readouts

feed() {
  while :; do
    ram=$(free -m 2>/dev/null | awk '/Mem:/{printf "%d", ($3/$2)*100}')
    bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    day=$(date '+%a %d %b %H:%M')
    line="%{r}%{F$AC}ram%{F$FG} ${ram}${P}   "
    [ -n "$bat" ] && line="${line}%{F$AC}bat%{F$FG} ${bat}${P}   "
    line="${line}%{F$FG}${day}  %{F-}"
    echo "$line"
    sleep 3
  done
}

# -p persistent · -g height 24 · Tokyo Night colours
feed | lemonbar -p -g x24 -B "$BG" -F "$FG" -f "$FONT"
