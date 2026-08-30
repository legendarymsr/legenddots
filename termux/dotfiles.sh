#!/usr/bin/env bash
# termux/dotfiles.sh — pull the repo and symlink the phone dotfiles in one shot,
# so nothing gets missed by hand-copying individual `ln` lines.
#
#   bash ~/legenddots/termux/dotfiles.sh
#
# Links the editor/multiplexer configs that make sense on the phone:
#   init.lua                 -> ~/.config/nvim/init.lua   (Neovim)
#   tmux.conf                -> ~/.config/tmux/tmux.conf   (tmux 3.1+ reads it there)
#   suckless/screen/screenrc -> ~/.screenrc                (GNU Screen)
#   suckless/vi/exrc         -> ~/.exrc                    (classic / busybox vi)
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
say()  { echo ":: $*"; }
warn() { echo "!! $*" >&2; }

# 1. refresh the clone so the symlink targets exist / are current
if [ -d "$REPO/.git" ]; then
  say "Updating $REPO ..."
  git -C "$REPO" pull --ff-only 2>/dev/null || git -C "$REPO" pull 2>/dev/null \
    || warn "git pull failed (offline?) — linking whatever is checked out"
fi

# 2. link helper: skip a missing source (so we never leave a dangling link — the
#    exact failure this script exists to prevent), back up a real file in the way,
#    then (re)create the symlink.
link() {
  local src="$1" dst="$2"
  if [ ! -e "$src" ]; then
    warn "missing in repo: $src — skipping (is your clone up to date?)"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    warn "backing up $dst -> ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi
  ln -sfn "$src" "$dst"
  say "linked $dst"
}

# 3. the phone dotfiles
link "$REPO/init.lua"                  "$HOME/.config/nvim/init.lua"
link "$REPO/tmux.conf"                 "$HOME/.config/tmux/tmux.conf"
link "$REPO/suckless/screen/screenrc"  "$HOME/.screenrc"
link "$REPO/suckless/vi/exrc"          "$HOME/.exrc"

echo
say "Done. Packages: pkg install neovim tmux screen git"
say "     classic vi for ~/.exrc: pkg install busybox  (see termux/README.md)"
