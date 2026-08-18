# guix

GNU Guix system + home config. Ratpoison WM, suckless tools (st, slock, dmenu),
Emacs, all Tokyo Night. Libre only.

## Files

| File | What |
|------|------|
| `config.scm` | System: kernel hardening, bootloader, filesystems, user, packages, services (openssh, nftables, fail2ban, apparmor, libvirt). Defines the custom suckless builds. |
| `home-configuration.scm` | Home: CLI tools, Emacs, zsh, and the dotfiles below. |
| `ratpoisonrc` | Ratpoison WM config → `~/.ratpoisonrc`. Prefix key is `C-t`. |
| `slock-config.h` | slock (screen locker) build config. |
| `dmenu-config.h` | dmenu (launcher) build config. |

## Suckless builds

st, slock, and dmenu are configured at **compile time**, so each gets a custom
package in `config.scm` (`st-tokyonight`, `slock-tokyonight`, `dmenu-tokyonight`).

- **slock / dmenu** copy the small `*-config.h` in before building — edit the
  file, then `guix system reconfigure`.
- **st** has no config file. A complete st `config.h` has to redefine st's whole
  keymap (~500 lines), so instead the package patches just the font and Tokyo
  Night palette into st's own `config.def.h` at build time. Edit those
  substitutions in `config.scm`.

`slock-tokyonight` is also registered in `setuid-programs` so it can
authenticate on unlock.

## Apply

```bash
guix system reconfigure guix/config.scm
guix home reconfigure guix/home-configuration.scm
```

## Notes

- Fill in `YOUR-EFI-UUID` and `YOUR-SWAP-UUID` in `config.scm` before applying.
- Ratpoison keybinds: prefix `C-t`, then `c` (st), `d` (dmenu), `e` (emacs),
  `b` (icecat), `Escape` (slock). See `ratpoisonrc` for the full list.
