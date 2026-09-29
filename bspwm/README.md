# bspwm — minimal setup

> Want dwm's minimalism without patching `config.h` and recompiling for every
> change? bspwm is a tiny C window manager that does nothing on its own — you
> drive it from a shell script and bind keys with sxhkd. No recompiles, no
> Haskell, no Rust.

A deliberately small bspwm rice: the window manager (sxhkd for keys), a lean
**lemonbar** (ram · battery · date, a pure-shell C bar — no Haskell), minimal
**picom / rofi / dunst**, **slock** for the screen lock, a **ly** login, and
**surf** for a browser (the one heavy piece — it pulls WebKit). Tokyo Night,
Super as the mod key.

## Install (Arch or KISS)

```sh
./install.sh
```

The script detects your distro:

- **Arch** — `pacman` installs everything (official repos), then enables `ly`
  via systemd. Reboot and pick **bspwm** at the login.
- **KISS** — `kiss` builds the tools. It's all plain **C** — no GHC/Rust
  toolchain to bootstrap — then it wires `~/.xinitrc` so you launch with
  **`startx`** (enabling `ly` is left to you; KISS isn't systemd).

Either way it symlinks the configs into `~/.config`, installs the `ly` config +
bspwm session, and sets `slock` setuid. (surf, like st, is configured at compile
time — no config file.)

## What's here

| file | linked to | what |
|------|-----------|------|
| `bspwmrc` | `~/.config/bspwm/bspwmrc` | the WM config — a shell script |
| `sxhkdrc` | `~/.config/sxhkd/sxhkdrc` | keybinds |
| `lemonbar/bar.sh` | `~/.config/lemonbar/bar.sh` | the bar — ram · battery · date (shell + lemonbar) |
| `picom.conf` | `~/.config/picom/picom.conf` | vsync, nothing else |
| `rofi/config.rasi` | `~/.config/rofi/config.rasi` | launcher (stock theme) |
| `dunst/dunstrc` | `~/.config/dunst/dunstrc` | notifications |
| `ly/config.ini` | `/etc/ly/config.ini` | display manager |
| `bspwm.desktop` | `/usr/share/xsessions/` | the session `ly` lists |

## Keys (super = Super)

| key | action |
|-----|--------|
| `super-Return` | st |
| `super-p` | rofi |
| `super-w` | surf |
| `super-q` / `super-shift-q` | close / kill window |
| `super-{h,j,k,l}` | focus in a direction |
| `super-shift-{h,j,k,l}` | move window |
| `super-{1..9}` | switch desktop |
| `super-shift-{1..9}` | send window to desktop |
| `super-t` / `super-shift-space` / `super-f` | tiled / floating / fullscreen |
| `super-shift-x` | **lock** (slock) |
| `super-alt-r` / `super-alt-q` | restart / quit bspwm |
| `super-Escape` | reload sxhkd |

Keys live in `sxhkdrc` — edit it and hit `super-Escape` to reload. No recompile.

## Lock

`slock` is a **graphical X screen locker**: `super-shift-x` blanks the screen and
locks until you type your password. `install.sh` sets it setuid so it can
authenticate.

## The bar

`lemonbar/bar.sh` is a tiny shell loop piped into **lemonbar** (C) — three
readouts: **ram**, **battery**, **date**, in Tokyo Night. On a machine with no
battery that readout just drops off. The font line needs a lemonbar built with
Xft (`lemonbar-xft`); on the plain core-font build, drop `-f "$FONT"`.

## Notes

- The terminal is **st**, built from source with your
  [`suckless/st/config.h`](../suckless/st/config.h) symlinked in — `install.sh`
  clones st into `~/.local/src/st`, links your config.h, and `make install`s it.
  Edit that config.h and rerun to rebuild. All C, no Rust.
- The bspwm config is `~/.config/bspwm/bspwmrc`, a shell script bspwm re-runs on
  `super-alt-r`; `sxhkd` owns the keys.
- Package names assume an Arch base, or your KISS repo checkout.
