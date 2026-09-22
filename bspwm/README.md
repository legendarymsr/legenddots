# bspwm — minimal setup

> Want dwm's minimalism without patching `config.h` and recompiling for every
> change? bspwm is a tiny C window manager that does nothing on its own — you
> drive it from a shell script and bind keys with sxhkd. No recompiles, no
> Haskell, no Rust.

A deliberately small bspwm rice: the window manager (sxhkd for keys), a lean
**polybar** (ram · battery · date), ultra-minimal **picom / rofi / dunst**,
**dillo** for a browser, a **ly** login, and a **TTY-style lock**. Tokyo Night,
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

Either way it symlinks the configs into `~/.config`, links the Dillo config
(`../scripts/dillo/`) into `~/.dillo/`, installs the `ly` config + bspwm session,
and sets `physlock` setuid.

## What's here

| file | linked to | what |
|------|-----------|------|
| `bspwmrc` | `~/.config/bspwm/bspwmrc` | the WM config — a shell script |
| `sxhkdrc` | `~/.config/sxhkd/sxhkdrc` | keybinds |
| `polybar/config.ini` | `~/.config/polybar/config.ini` | the bar — ram · battery · date |
| `polybar/launch.sh` | `~/.config/polybar/launch.sh` | (re)start the bar |
| `picom.conf` | `~/.config/picom/picom.conf` | vsync, nothing else |
| `rofi/config.rasi` | `~/.config/rofi/config.rasi` | launcher (stock theme) |
| `dunst/dunstrc` | `~/.config/dunst/dunstrc` | notifications |
| `ly/config.ini` | `/etc/ly/config.ini` | display manager |
| `bspwm.desktop` | `/usr/share/xsessions/` | the session `ly` lists |

## Keys (super = Super)

| key | action |
|-----|--------|
| `super-Return` | alacritty |
| `super-p` | rofi |
| `super-w` | dillo |
| `super-q` / `super-shift-q` | close / kill window |
| `super-{h,j,k,l}` | focus in a direction |
| `super-shift-{h,j,k,l}` | move window |
| `super-{1..9}` | switch desktop |
| `super-shift-{1..9}` | send window to desktop |
| `super-t` / `super-shift-space` / `super-f` | tiled / floating / fullscreen |
| `super-shift-x` | **lock** (physlock) |
| `super-alt-r` / `super-alt-q` | restart / quit bspwm |
| `super-Escape` | reload sxhkd |

Keys live in `sxhkdrc` — edit it and hit `super-Escape` to reload. No recompile.

## Lock (TTY-style)

`physlock` is a **console locker**, not a graphical lockscreen: `super-shift-x`
drops to a bare console and locks every VT until you type your password.
`install.sh` sets it setuid; prefer not to? Add a `doas` rule and change the
bind to `doas physlock`.

## The bar

polybar, one bar, three modules: **ram**, **battery**, **date**. Set the battery
names for your hardware in `config.ini` (`ls /sys/class/power_supply`); on a
desktop with no battery the module just shows nothing.

## Notes

- The bspwm config is `~/.config/bspwm/bspwmrc`, a shell script bspwm re-runs on
  `super-alt-r`; `sxhkd` owns the keys.
- Package names assume an Arch base, or your KISS repo checkout.
