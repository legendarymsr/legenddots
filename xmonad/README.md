# xmonad — minimal XMonad setup

> So you suck at suckless but still want minimal? XMonad is about as close as
> you'll get — same tiling spirit as dwm, but you configure it in one file it
> recompiles itself, instead of patching `config.h` in C by hand.

A deliberately small XMonad rice: the window manager, a bare **xmobar**
(ram · battery · date), ultra-minimal **picom / rofi / dunst**, a **ly** login,
and a **TTY-style lock**. Tokyo Night, Super as the mod key. No workspace applet,
no system tray, no gaps — just enough to live in.

## Install (Arch or KISS)

```sh
./install.sh
```

The script detects your distro and does the right thing:

- **Arch** — `pacman` installs everything (official repos, no AUR), then it
  enables `ly` via systemd. Reboot and pick **XMonad** at the login.
- **KISS** — `kiss` builds the tools; since KISS ships no `ghc`, it bootstraps
  the Haskell toolchain with **ghcup** and builds `xmonad`/`xmobar` with cabal.
  It wires up `~/.xinitrc` so you launch with **`startx`** (enabling `ly` is left
  to you — KISS isn't systemd). `doas` is used for the root steps.

Either way it symlinks the configs into `~/.config`, installs the `ly` config +
XMonad session, and sets `physlock` setuid for the TTY lock.

> The KISS installer (`../kiss/`) already runs this same desktop build during a
> fresh install; use this script to add XMonad to an already-running system.

## What's here

| file | linked to | what |
|------|-----------|------|
| `xmonad.hs` | `~/.config/xmonad/xmonad.hs` | the whole window manager |
| `xmobarrc` | `~/.xmobarrc` | the bar — ram · battery · date |
| `picom.conf` | `~/.config/picom/picom.conf` | vsync, nothing else |
| `rofi/config.rasi` | `~/.config/rofi/config.rasi` | launcher (stock theme, no icons) |
| `dunst/dunstrc` | `~/.config/dunst/dunstrc` | notifications |
| `ly/config.ini` | `/etc/ly/config.ini` | display manager |
| `xmonad.desktop` | `/usr/share/xsessions/` | the session `ly` lists |

## Keys (Mod = Super)

| key | action |
|-----|--------|
| `Mod-Return` | alacritty |
| `Mod-p` | rofi |
| `Mod-Space` | cycle layout |
| `Mod-b` | toggle the bar |
| `Mod-Shift-c` | close window |
| `Mod-Shift-l` | **lock** (physlock) |
| `Mod-q` | recompile this config & restart |
| `Mod-Shift-q` | quit XMonad (drops to the tty under startx) |

Plus the XMonad defaults: `Mod-1..9` switch workspace, `Mod-Shift-1..9` move a
window there, `Mod-j`/`Mod-k` focus, `Mod-h`/`Mod-l` resize the master pane.

## Lock (TTY-style)

`physlock` is a **console locker**, not a graphical lockscreen: `Mod-Shift-l`
switches to a bare console and locks every virtual terminal until you type your
password — exactly the "TTY lock" feel.

It needs root, so `install.sh` makes it setuid:

```sh
sudo chmod u+s /usr/bin/physlock
```

Prefer not to setuid it? Drop a `doas`/`sudo` rule for `physlock` and change the
keybind to `doas physlock` instead.

## The bar

xmobar, kept bare on purpose — `ram <usedratio>%`, `bat <left>%`, and the date.
**On a desktop**, delete the `Battery` line in `xmobarrc` (there's nothing for it
to read). Add more by dropping extra `Run …` commands into `commands` and fields
into `template`.

## Notes

- Config path is the XDG `~/.config/xmonad/`; `xmonad --recompile` (and
  `Mod-q`) rebuild from there. Needs `ghc`, which the `xmonad` package pulls in.
- Package names assume an Arch base, like the other rices in this repo.
