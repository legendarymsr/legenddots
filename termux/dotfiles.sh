#!/usr/bin/env bash
# termux/dotfiles.sh — pull the repo and symlink the phone dotfiles in one shot,
# so nothing gets missed by hand-copying individual `ln` lines.
#
#   bash ~/legenddots/termux/dotfiles.sh
#
# Links the editor/multiplexer configs that make sense on the phone:
#   .zshrc                       -> ~/.zshrc                          (zsh config)
#   init.lua                     -> ~/.config/nvim/init.lua           (Neovim)
#   tmux.conf                    -> ~/.config/tmux/tmux.conf          (tmux 3.1+)
#   suckless/screen/screenrc     -> ~/.screenrc                        (GNU Screen)
#   suckless/vis/visrc.lua       -> ~/.config/vis/visrc.lua            (vis: Lua, no VimL)
#   suckless/vis/themes/*.lua    -> ~/.config/vis/themes/tokyonight.lua (Tokyo Night)
#   suckless/vi/exrc             -> ~/.exrc                             (POSIX vi baseline)
#   termux/colors.properties     -> ~/.termux/colors.properties         (Tokyo Night terminal)
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

# make our .zshrc authoritative: remove any existing zsh rc (a real file, or a
# foreign symlink from another setup) so nothing shadows it — link recreates it.
for z in "$HOME/.zshrc" "$HOME/.zshrc.pre-oh-my-zsh"; do
  { [ -e "$z" ] || [ -L "$z" ]; } || continue
  case "$(readlink "$z" 2>/dev/null)" in
    */legenddots/.zshrc) ;;                        # already ours — keep
    *) rm -f "$z" && say "removed existing zsh config: $z" ;;
  esac
done

link "$REPO/.zshrc"                              "$HOME/.zshrc"
link "$REPO/init.lua"                           "$HOME/.config/nvim/init.lua"
link "$REPO/tmux.conf"                           "$HOME/.config/tmux/tmux.conf"
link "$REPO/suckless/screen/screenrc"            "$HOME/.screenrc"
link "$REPO/suckless/vis/visrc.lua"              "$HOME/.config/vis/visrc.lua"
link "$REPO/suckless/vis/themes/tokyonight.lua"  "$HOME/.config/vis/themes/tokyonight.lua"
link "$REPO/suckless/vi/exrc"                    "$HOME/.exrc"
link "$REPO/termux/colors.properties"            "$HOME/.termux/colors.properties"

# 4. cleanup of earlier versions of this script:
#  a) it used to link ~/.vimrc to the (now removed) vim config — drop that dangling link
if [ -L "$HOME/.vimrc" ]; then
  case "$(readlink "$HOME/.vimrc")" in
    */legenddots/suckless/vim/vimrc)
      rm -f "$HOME/.vimrc" && say "removed the stale ~/.vimrc symlink (vim dropped; vis now)" ;;
  esac
fi
#  b) it used to append a busybox-vi EXINIT line to the shell rc — strip it back out.
#     Matches both the commented line it wrote and the bare one-liner from the old README.
EXINIT_PAT="export EXINIT='set autoindent ignorecase showmatch tabstop=4'"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -e "$rc" ] || continue
  if grep -qF "$EXINIT_PAT" "$rc" 2>/dev/null; then
    sed -i "\|$EXINIT_PAT|d" "$rc"
    say "removed the old busybox-vi EXINIT line from $(basename "$rc")"
  fi
done

# 5. apply the Termux terminal colours right away (no-op off Termux)
if command -v termux-reload-settings >/dev/null 2>&1; then
  termux-reload-settings && say "reloaded Termux settings — Tokyo Night terminal applied"
fi

# 6. make zsh the default login shell (Termux only — don't touch a desktop shell)
if { [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux ]; } \
   && command -v zsh >/dev/null 2>&1 && command -v chsh >/dev/null 2>&1; then
  case "${SHELL:-}" in
    */zsh) say "zsh is already the default shell" ;;
    *) chsh -s zsh && say "default shell -> zsh (restart Termux to apply)" \
         || warn "chsh -s zsh failed — run 'chsh -s zsh' yourself" ;;
  esac
fi

echo
say "Done. Packages: pkg install zsh neovim tmux screen vis git"
say "zsh set as default (restart Termux to take effect); ~/.zshrc is yours."
say "vis uses ~/.config/vis/visrc.lua (Tokyo Night); ~/.exrc is the vi baseline."
say "Termux terminal is themed via ~/.termux/colors.properties (Tokyo Night)."
