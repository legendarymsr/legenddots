# suckless

[suckless](https://suckless.org) tool configs. Each program is configured at
**compile time** via a `config.h`, so these are build inputs, not runtime
dotfiles — edit one, then rebuild that program. All themed **Tokyo Night**,
**JetBrains Mono**.

| Tool | What | `config.h` |
|------|------|-----------|
| **st** | terminal | `st/config.h` — trimmed: no F13–F35, no keypad, no mouse |
| **slock** | screen locker | `slock/config.h` — Tokyo Night lock colors |
| **dmenu** | launcher | `dmenu/config.h` — Tokyo Night + font |
| **dwm** | X11 tiling WM | `dwm/config.h` — Super mod, hjkl, st + dmenu |
| **dwl** | Wayland tiling WM (dwm-alike) | `dwl/config.h` — Super mod, foot + fuzzel |
| **surf** | WebKit browser | `surf/config.h` — behaviour/keybinds (colors via user CSS) |

## Building

suckless programs copy `config.def.h` → `config.h` only if `config.h` is
absent, so dropping one of these in before `make` bakes it in:

```sh
git clone https://git.suckless.org/dwm && cd dwm
cp ~/legenddots/suckless/dwm/config.h config.h
sudo make clean install
```

Same pattern for `st`, `slock`, `dmenu`, `dwl`, `surf`.

## Guix

On Guix, `st`, `slock`, and `dmenu` are built declaratively — `guix/config.scm`
defines `st-tokyonight` / `slock-tokyonight` / `dmenu-tokyonight` packages that
copy `../suckless/<tool>/config.h` in before compiling. Edit the file here, then
`guix system reconfigure guix/config.scm`.

## Notes

- **dwm** uses `Super` as the modifier (`Super+Return` st, `Super+d` dmenu,
  `Super+b` icecat, `Super+e` emacs, `Super+Escape` slock, `Super+Shift+q` close).
- **dwl** mirrors dwm's binds on Wayland (`foot` + `fuzzel`). Vanilla dwl has no
  autostart, so launch the wallpaper (`wbg`/`swaybg`) from your session script.
- **surf** page theming is a user stylesheet in `~/.surf/styles/`; `config.h`
  only sets behaviour (privacy defaults, DarkMode on) and keybinds (`Ctrl`-based,
  surf's convention).
