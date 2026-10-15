#!/bin/sh
# gentoo/chroot/dotfiles.sh — link legenddots into the Gentoo arm64 chroot
# (Larry Launcher). Idempotent; run as often as you like:
#
#   sh ~/legenddots/gentoo/chroot/dotfiles.sh
#   HOME=/home/legend sh /opt/legenddots/gentoo/chroot/dotfiles.sh --no-pull
#
# Run as root for another HOME, the links and the dirs made for them are
# chowned to the owner of that HOME.
#
#   init.lua              -> ~/.config/nvim/init.lua
#   tmux.conf             -> ~/.config/tmux/tmux.conf and ~/.tmux.conf
#   foot/foot.ini         -> ~/.config/foot/foot.ini
#   niri/fuzzel           -> ~/.config/fuzzel
#   fastfetch             -> ~/.config/fastfetch
#   dillo/dillorc, keysrc -> ~/.dillo/
#
# niri's config.kdl is NOT linked: the launcher writes ~/.config/niri/config.kdl
# itself (nested winit output scaled to the phone), and niri/config.kdl here is
# the bare-metal session (waybar, alacritty, brave) that can't run nested.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
say()  { echo ":: $*"; }
warn() { echo "!! $*" >&2; }

if [ -d "$REPO/.git" ] && [ "${1:-}" != "--no-pull" ]; then
  git -C "$REPO" pull --ff-only -q 2>/dev/null || warn "git pull failed (offline?), linking what is checked out"
fi

# Who owns $HOME: links made as root for another user's home are given to them.
OWNER="$(stat -c %u:%g "$HOME" 2>/dev/null || echo)"
own() { [ "$(id -u)" = 0 ] && [ -n "$OWNER" ] && [ "$OWNER" != "0:0" ] && chown -h "$OWNER" "$@" 2>/dev/null; true; }

link() {
  src="$1" dst="$2"
  [ -e "$src" ] || { warn "missing in repo: $src, skipping"; return; }
  [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && return
  dir="$(dirname "$dst")"
  [ -d "$dir" ] || { mkdir -p "$dir" && own "$dir"; }
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    # Never move a real dir into an older backup: number the backup instead.
    bak="$dst.bak"; n=1
    while [ -e "$bak" ] || [ -L "$bak" ]; do bak="$dst.bak.$n"; n=$((n + 1)); done
    warn "backing up $dst -> $bak"
    mv "$dst" "$bak" || { warn "could not move $dst aside, skipping"; return; }
  fi
  ln -sfn "$src" "$dst" && own "$dst" && say "linked $dst"
}

[ -d "$HOME/.config" ] || { mkdir -p "$HOME/.config" && own "$HOME/.config"; }

link "$REPO/init.lua"          "$HOME/.config/nvim/init.lua"
link "$REPO/tmux.conf"         "$HOME/.config/tmux/tmux.conf"
link "$REPO/tmux.conf"         "$HOME/.tmux.conf"
link "$REPO/foot/foot.ini"     "$HOME/.config/foot/foot.ini"
link "$REPO/niri/fuzzel"       "$HOME/.config/fuzzel"
link "$REPO/fastfetch"         "$HOME/.config/fastfetch"
link "$REPO/dillo/dillorc"     "$HOME/.dillo/dillorc"
link "$REPO/dillo/keysrc"      "$HOME/.dillo/keysrc"
