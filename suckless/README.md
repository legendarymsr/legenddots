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
| **dwl** | Wayland tiling WM (dwm-alike) | `dwl/config.h` — Super mod, foot + wmenu, `Mod+Esc` lock |
| **dwlb** | status bar for dwl | `dwlb/config.h` — Tokyo Night, `hide_vacant`, JetBrainsMono |
| **surf** | WebKit browser | `surf/config.h` — behaviour/keybinds (colors via user CSS) |

### Also here — not suckless, but same spirit

Minimal **screen** and **vim** configs, kept for the minimalist collection. Unlike
everything above, these are **runtime dotfiles**, not compile-time `config.h` — so
you *symlink* them, no rebuild.

| Tool | What | file | symlink to |
|------|------|------|-----------|
| **screen** | terminal multiplexer (GNU) | `screen/screenrc` | `~/.screenrc` |
| **vim** | very minimal vim config | `vim/vimrc` | `~/.vimrc` |
| **foot** | Wayland terminal (dwl's `termcmd`) | `foot/foot.ini` | `~/.config/foot/foot.ini` |
| **wmenu** | Wayland launcher (dwl's `menucmd`) | `wmenu/menu` | `~/.local/bin/menu` |
| **swaylock** | Wayland screen locker (dwl's `Mod+Esc`) | `swaylock/config` | `~/.config/swaylock/config` |

```sh
ln -sfn "$PWD/screen/screenrc" ~/.screenrc
ln -sfn "$PWD/vim/vimrc"       ~/.vimrc
ln -sfn "$PWD/foot/foot.ini"   ~/.config/foot/foot.ini
ln -sfn "$PWD/wmenu/menu"      ~/.local/bin/menu          # dwl runs `menu` on Mod+d
ln -sfn "$PWD/swaylock/config" ~/.config/swaylock/config  # dwl locks with Mod+Esc
```

**foot + wmenu complement dwl.** dwl's `config.h` launches `foot` (`Mod+Return`)
and `menu` (`Mod+d`). `foot/foot.ini` themes foot Tokyo Night + JetBrainsMono to
match st. **wmenu has no config file** — it's configured by flags — so
`wmenu/menu` is a tiny wrapper that runs `wmenu-run` with the theme; dwl calls it
by name (`menucmd = { "menu" }`), so keep it on `PATH`. Install the programs with
`gui-apps/foot` + `gui-apps/wmenu` (Gentoo; wmenu is in the GURU overlay),
`foot wmenu` (Arch/nixpkgs).

**dwlb** is dwl's bar (dwl ships none). It's compile-time like the other suckless
tools — drop `dwlb/config.h` in before `make`, then start it *attached to dwl* so
it gets the tag/title/status feed:

```sh
dwl -s 'dwlb -font "JetBrainsMono Nerd Font:size=11"'   # or just: dwl -s dwlb
```

Feed the status text (right side) with anything that prints lines — e.g.
`while :; do date "+%H:%M"; sleep 30; done | dwlb -status-stdin all`. Install:
`gui-apps/dwlb` (GURU) / build from `github.com/kolunmi/dwlb`.

**swaylock** handles locking — dwl has no built-in locker, and `slock` above is
X11-only, so on Wayland this is the one. `Mod+Esc` in `dwl/config.h` runs
`swaylock`, which reads `~/.config/swaylock/config` — ours is one line, a solid
Tokyo Night background (`color=1a1b26`); the password ring stays swaylock's
default. Install `gui-apps/swaylock` (Gentoo) / `swaylock` (Arch/nixpkgs).

**screen** is a real program (package `app-misc/screen` on Gentoo, `screen` on
Arch / nixpkgs / Guix). **vim is config-only** — we ship a tiny `~/.vimrc`; install
vim yourself (it's a vi, and it's in every main repo, Termux included). The vimrc is
deliberately bare: `syntax on` and `tabstop`/`shiftwidth=4` — nothing else.

**Optional C/C++ LSP** (`vim/c-lsp.vim`) — kept out of the base vimrc so that stays
minimal. It's the dead-simplest LSP path for real Vim (Vim has no built-in client):
the pure-Vim9 [`yegappan/lsp`](https://github.com/yegappan/lsp) plugin driving
`clangd` — no node, no python, no plugin manager. Install:

```sh
git clone https://github.com/yegappan/lsp ~/.vim/pack/lsp/start/lsp   # Vim native packages
echo 'source ~/legenddots/suckless/vim/c-lsp.vim' >> ~/.vimrc          # opt in
```

Then `clangd` starts on `.c`/`.cpp` buffers; keys: `gd` def, `gr` refs, `K` hover,
`grn` rename, `gra` code action. (Needs Vim 9 and `clangd` on `PATH`.)

**Declaratively you don't symlink by hand:**

- **home-manager** (`legend.suckless.enable = true`) installs `screen`, links
  `~/.screenrc`, and links `~/.vimrc` (config only, vim not installed). Turn either off
  with `legend.suckless.screen.enable = false` / `legend.suckless.vim.enable = false`.
- **Guix Home** (`home-configuration.scm`) installs `screen` and places both dotfiles
  via `home-files-service-type`. The `config.scm` manifest also carries `screen`.

The manual `ln -sfn` above is only for non-declarative setups.

---

## Config reference

The `config.h` files are kept **comment-free** — what each thing does lives here
instead. All Tokyo Night (`bg #1a1b26`, `fg #c0caf5`, `dim #414868`, `accent/blue
#7aa2f7`, `urgent/red #f7768e`), JetBrainsMono Nerd Font size 11.

### dwm (X11) & dwl (Wayland) — same scheme

Mod is **Super** (`Mod4` / `LOGO`). dwm spawns `st` + `dmenu` + `slock`; dwl spawns
`foot` + `menu` (wmenu) + `swaylock`.

| Key | Action |
|-----|--------|
| `Mod+Return` | terminal |
| `Mod+d` | launcher |
| `Mod+b` / `Mod+e` | icecat / emacs |
| `Mod+Esc` | lock screen |
| `Mod+j` / `Mod+k` | focus next / prev window |
| `Mod+h` / `Mod+l` | shrink / grow master area |
| `Mod+i` / `Mod+o` | more / fewer master windows |
| `Mod+space` | zoom (promote to master) |
| `Mod+t` / `Mod+f` / `Mod+m` | tile / floating / monocle layout |
| `Mod+Shift+space` | toggle floating |
| `Mod+Shift+q` (dwl) / `Mod+Shift+c` (dwm) | kill window |
| `Mod+F11` (dwl) | fullscreen |
| `Mod+1..9` | view tag · `+Shift` move window · `+Ctrl` toggle-view · `+Ctrl+Shift` toggle-tag |
| `Mod+0` | view all tags · `Mod+Tab` last tag |
| `Mod+,` / `Mod+.` | focus monitor left / right (`+Shift` moves the window) |
| `Mod+Shift+e` | quit the WM · dwl: `Ctrl+Alt+F1..F12` switch VT |

**Rules:** Gimp floats; IceCat opens on tag 9. **Layouts:** tile `[]=`, float `><>`,
monocle `[M]`; master factor `0.55`, 1 master.

### st

Trimmed from stock: **no** F13–F35 keys, **no** keypad table, **no** mouse
shortcuts (keyboard-only) — the source references still exist so it compiles clean.
`shell=/bin/sh`, `borderpx=12`, `tabspaces=8`, `termname=st-256color`. The 16-colour
`colorname[]` is the Tokyo Night palette (256→fg, 257→bg, 258→cursor).

### surf

Mod is **Ctrl**. `Ctrl+g` = go (URL prompt), `Ctrl+f` = find; standard surf binds
otherwise. Behaviour flags only — page colours come from your user CSS. Keeps the
`suckless.org` cert-pinning regex and the `SETPROP`/`DOWNLOAD`/`PLUMB`/`VIDEOPLAY`
helper macros.

### slock / dmenu

**slock** drops privileges to `nobody` after locking; three Tokyo Night states —
idle (init), input, wrong-password — and treats a cleared field as a wrong attempt.
**dmenu** is themed to match (`-nb/-nf/-sb/-sf`), JetBrainsMono; add `-b` for a
bottom bar or `-l N` for a vertical list at runtime.

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

### LFS / BLFS — full from-source

No package manager: everything is built from source. This repo already ships two
complete LFS builders — **run one first** as your base, then build the delta below.

- **`libre/setup`** (X11 base) builds the whole toolchain + X client libs
  (libX11, libXft, libXinerama, libXext, libXrandr), freetype, fontconfig,
  pixman, libevdev, mtdev, libtasn1, p11-kit, cairo. After it, **st, dmenu, dwm,
  slock need nothing more** — skip to *The tools* at the bottom.
- **`blfs/setup`** (Wayland base) builds the toolchain + wayland,
  wayland-protocols, libxkbcommon, pixman, libdrm, mesa, seatd, GLib, GTK+3,
  cairo, pango, gdk-pixbuf, harfbuzz, libwebp, at-spi2. Everything below is what
  it *doesn't* build, needed for **dwl** and **surf**.

**Build patterns** (run each package's block, then `cd ..`):

- autotools — `./configure --prefix=/usr --disable-static && make && sudo make install`
- meson — `meson setup --prefix=/usr --buildtype=release build && ninja -C build && sudo ninja -C build install`
- cmake — `cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release && ninja -C build && sudo ninja -C build install`

Fetch with `curl -LO <url>` then `tar xf <file> && cd <dir>`. Versions are a
known-good set — bump to match your LFS release.

#### dwl deps (on the `blfs/setup` base), in order

```sh
# libevdev  (meson)  https://www.freedesktop.org/software/libevdev/libevdev-1.13.3.tar.xz
# mtdev     (autotools) https://bitmath.org/code/mtdev/mtdev-1.1.7.tar.bz2
# libinput  (meson, -Dtests=false -Ddebug-gui=false -Ddocumentation=false)
#           https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.27.1/libinput-1.27.1.tar.gz
# tllist    (meson)  https://codeberg.org/dnkl/tllist/archive/1.1.0.tar.gz
# fcft      (meson, -Dgrapheme-shaping=disabled -Drun-shaping=disabled)
#           https://codeberg.org/dnkl/fcft/archive/3.3.1.tar.gz
# wlroots   (meson, -Dexamples=false)  0.18 — matches dwl 0.7
#           https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.18.2/wlroots-0.18.2.tar.gz

# e.g. wlroots:
curl -LO https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.18.2/wlroots-0.18.2.tar.gz
tar xf wlroots-0.18.2.tar.gz && cd wlroots-0.18.2
meson setup --prefix=/usr --buildtype=release -Dexamples=false build
ninja -C build && sudo ninja -C build install && cd ..
```

#### surf deps (on the `blfs/setup` base), in order

GTK+3, GLib, cairo, pango, gdk-pixbuf, harfbuzz and libwebp already come from
`blfs/setup`. Build the crypto stack, then the engine:

```sh
# --- crypto / gcr chain ---
# libgpg-error 1.51        (autotools)  https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.51.tar.bz2
# libgcrypt 1.11.0         (autotools, --with-libgpg-error-prefix=/usr)
#                          https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.0.tar.bz2
# libtasn1 4.20.0          (autotools)  https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz
# p11-kit 0.25.5           (meson)      https://github.com/p11-glue/p11-kit/releases/download/0.25.5/p11-kit-0.25.5.tar.xz
# gcr 3.41.2               (meson, -Dgtk_doc=false)  https://download.gnome.org/sources/gcr/3.41/gcr-3.41.2.tar.xz

# --- webkit2gtk engine chain ---
# ICU 76.1                 (autotools, build in the source/ subdir)
#                          https://github.com/unicode-org/icu/releases/download/release-76-1/icu4c-76_1-src.tgz
#                          cd icu/source && ./configure --prefix=/usr && make && sudo make install
# sqlite 3.47.2            (autotools)  https://sqlite.org/2024/sqlite-autoconf-3470200.tar.gz
# libpsl 0.21.5            (meson)      https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz
# libsoup 3.6.0            (meson, -Dvapi=disabled -Dgssapi=disabled -Dtests=false -Dsysprof=disabled)
#                          https://download.gnome.org/sources/libsoup/3.6/libsoup-3.6.0.tar.xz
# woff2 1.0.2              (cmake; needs brotli, present via freetype)  https://github.com/google/woff2/archive/v1.0.2/woff2-1.0.2.tar.gz
# libwpe 1.16.0            (meson)      https://wpewebkit.org/releases/libwpe-1.16.0.tar.xz
# wpebackend-fdo 1.14.2    (meson)      https://wpewebkit.org/releases/wpebackend-fdo-1.14.2.tar.xz
# webkit2gtk 2.46.x        (cmake — LARGE, a multi-hour build):
curl -LO https://webkitgtk.org/releases/webkitgtk-2.46.5.tar.xz
tar xf webkitgtk-2.46.5.tar.xz && cd webkitgtk-2.46.5
cmake -B build -G Ninja -DPORT=GTK -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_GAMEPAD=OFF -DENABLE_MINIBROWSER=ON -DUSE_SYSTEMD=OFF -DUSE_JPEGXL=OFF -DUSE_LIBBACKTRACE=OFF -Wno-dev
ninja -C build && sudo ninja -C build install && cd ..
```

> webkit2gtk's exact flags/deps drift between releases — cross-check the
> [BLFS webkit2gtk page](https://www.linuxfromscratch.org/blfs/view/stable/x/webkit2gtk.html)
> for your version.

#### The tools

With the deps above in place, build each suckless program against our `config.h`.
Most live on suckless git; **dwl** is on codeberg:

```sh
build() {   # build <name> <git-url>
  git clone "$2" "/tmp/$1" && cp ~/legenddots/suckless/$1/config.h "/tmp/$1/config.h"
  ( cd "/tmp/$1" && sudo make clean install )
}
build st    https://git.suckless.org/st
build slock https://git.suckless.org/slock
build dmenu https://git.suckless.org/dmenu
build dwm   https://git.suckless.org/dwm
build surf  https://git.suckless.org/surf
build dwl   https://codeberg.org/dwl/dwl
```

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
