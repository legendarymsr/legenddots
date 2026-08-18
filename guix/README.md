# guix

GNU Guix system + home config. Ratpoison WM, suckless tools (st, slock, dmenu),
Emacs, all Tokyo Night. Libre only.

## Files

| File | What |
|------|------|
| `config.scm` | System: kernel hardening, bootloader, filesystems, user, packages, services (openssh, nftables, fail2ban, apparmor, libvirt). Defines the custom suckless builds. |
| `home-configuration.scm` | Home: CLI tools, Emacs, zsh, and the dotfiles below. |
| `ratpoisonrc` | Ratpoison WM config → `~/.ratpoisonrc`. Prefix key is `C-t`. |
| `st-config.h` | st (terminal) build config. |
| `slock-config.h` | slock (screen locker) build config. |
| `dmenu-config.h` | dmenu (launcher) build config. |

## Suckless builds

st, slock, and dmenu are configured at **compile time** via `config.h`, so each
gets a custom package in `config.scm` (`st-tokyonight`, `slock-tokyonight`,
`dmenu-tokyonight`) that copies the matching `*-config.h` in before building.
Edit a `*-config.h`, then `guix system reconfigure` to rebuild.

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
