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

---

## Declarative builds (NixOS / Guix)

You don't have to build by hand — this folder is self-contained.

### NixOS — flake + home-manager

`flake.nix` rebuilds each tool from nixpkgs against our `config.h`.

```sh
nix build   ./suckless#dwm          # build one
nix profile install ./suckless#st   # install one
nix develop ./suckless              # a shell with all the build deps
```

Home-manager (flake):

```nix
# flake.nix inputs:  suckless.url = "github:legendarymsr/legenddots?dir=suckless";
# home.nix:
imports = [ inputs.suckless.homeManagerModules.default ];
legend.suckless.enable = true;               # installs st slock dmenu dwm dwl surf
# legend.suckless.tools = [ ... ];           # or pick a subset
```

Non-flake home-manager: `imports = [ ./suckless/home.nix ];` then the same
`legend.suckless.enable = true;`.

### Guix — manifest + home

`config.scm` and `home-configuration.scm` define the same tools (inheriting the
Guix packages, dropping our `config.h` in before build).

```sh
guix shell   -m suckless/config.scm              # ephemeral shell with the tools
guix package -m suckless/config.scm              # install into your profile
guix home reconfigure suckless/home-configuration.scm   # via Guix Home
```

Or lift `%suckless-packages` into your own `operating-system` / `home-environment`.
The main `guix/config.scm` already does this for st/slock/dmenu (with slock
setuid). **surf isn't packaged in Guix** — build it from source (deps below).

---

## Dependencies (building by hand)

Everything needs a C compiler, `make`, and `pkg-config`.

- **st / dmenu / dwm** — libX11, libXft, libXinerama, fontconfig, freetype
- **slock** — libX11, libXext, libXrandr
- **surf** — gtk+3, webkit2gtk, glib, gcr, libX11
- **dwl** — wlroots, wayland, wayland-protocols, libinput, libxkbcommon, pixman, fcft

### Arch

```sh
sudo pacman -S --needed base-devel libx11 libxft libxinerama libxext libxrandr fontconfig freetype2
sudo pacman -S --needed gtk3 webkit2gtk gcr                                   # surf
sudo pacman -S --needed wlroots wayland wayland-protocols libinput libxkbcommon pixman fcft  # dwl
```

### Gentoo

```sh
sudo emerge -av x11-libs/libX11 x11-libs/libXft x11-libs/libXinerama \
  x11-libs/libXext x11-libs/libXrandr media-libs/fontconfig media-libs/freetype
sudo emerge -av x11-libs/gtk+:3 net-libs/webkit-gtk app-crypt/gcr            # surf
sudo emerge -av gui-libs/wlroots dev-libs/wayland dev-libs/wayland-protocols \
  dev-libs/libinput x11-libs/libxkbcommon x11-libs/pixman gui-libs/libfcft   # dwl
```

### NixOS

No manual deps — use the flake above. `nix develop ./suckless` gives a shell
with all build inputs, or `nix profile install ./suckless#<tool>` builds it
with its closure.

### Guix

No manual deps — `guix shell -m suckless/config.scm` handles them. To hack on a
config by hand:

```sh
guix shell gcc-toolchain make pkg-config libx11 libxft libxinerama libxext \
  libxrandr fontconfig freetype -- make
```

### LFS / BLFS

Build the deps from source per the [BLFS book](https://www.linuxfromscratch.org/blfs/).
The X stack (libX11, libXft, libXinerama, libXext, libXrandr, fontconfig,
freetype) and — for dwl — the Wayland stack (wayland, wayland-protocols,
wlroots, libinput, libxkbcommon, pixman) are already built by this repo's
`blfs/setup` and `libre/setup`. Extra for **surf**: webkit2gtk (a large BLFS
package) + gtk3 + gcr. Extra for **dwl**: fcft.

---

## Building by hand

suckless programs copy `config.def.h` → `config.h` only if `config.h` is
absent, so dropping one of these in before `make` bakes it in:

```sh
git clone https://git.suckless.org/dwm && cd dwm
cp ~/legenddots/suckless/dwm/config.h config.h
sudo make clean install
```

Same pattern for `st`, `slock`, `dmenu`, `dwl`, `surf`.

---

## Notes

- **dwm** uses `Super` as the modifier (`Super+Return` st, `Super+d` dmenu,
  `Super+b` icecat, `Super+e` emacs, `Super+Escape` slock, `Super+Shift+q` close).
- **dwl** mirrors dwm's binds on Wayland (`foot` + `fuzzel`). Vanilla dwl has no
  autostart, so launch the wallpaper (`wbg`/`swaybg`) from your session script.
- **surf** page theming is a user stylesheet in `~/.surf/styles/`; `config.h`
  only sets behaviour (privacy defaults, DarkMode on) and keybinds (`Ctrl`-based,
  surf's convention).
- **slock** must be setuid-root to authenticate on unlock — `sudo make install`
  handles it; on Guix it's a `setuid-program` (see `guix/config.scm`).
