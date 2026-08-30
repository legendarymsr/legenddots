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

# 4. busybox vi can't read ~/.exrc (that path is unimplemented in busybox) — it
#    only honours the EXINIT env var (one ':' command). Mirror the .exrc's core
#    options into EXINIT via the shell rc, using the subset busybox vi supports.
#    (A real nvi still reads the ~/.exrc linked above; this just fixes busybox vi.)
EXINIT_LINE="export EXINIT='set autoindent ignorecase showmatch tabstop=4'  # busybox vi; real nvi reads ~/.exrc"
rc_done=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -e "$rc" ] || continue
  rc_done=1
  grep -q 'EXINIT=' "$rc" 2>/dev/null && continue
  printf '\n%s\n' "$EXINIT_LINE" >> "$rc"
  say "added EXINIT to $(basename "$rc") (busybox vi config)"
done
if [ "$rc_done" = 0 ]; then
  printf '%s\n' "$EXINIT_LINE" >> "$HOME/.bashrc"
  say "created ~/.bashrc with EXINIT (busybox vi config)"
fi

echo
say "Done. Packages: pkg install neovim tmux screen git   (+ busybox for a minimal vi)"
say "Open a new shell (or 'source ~/.bashrc') so EXINIT takes effect for busybox vi."
