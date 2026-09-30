# alpine — minimal Alpine riscv64 desktop (StarFive VisionFive 2)

A deliberately tiny desktop for a **RISC-V** board: **bspwm + xterm + vis + lynx**,
every piece a **binary `apk` package — nothing compiled**. This is the KISS/suckless
idea *adapted to slow silicon*: on a 1.5 GHz SiFive U74, the suckless "just recompile
`config.h`" loop is misery, so the terminal is themed via `~/.Xresources`, the WM via
runtime `~/.config`, and vis via Lua. No source builds, no GPU/compositor.

> **Why not Gentoo/Exherbo here?** Those are my daily-driver, source-based systems.
> On a VF2 a full source distro means overnight compiles. Alpine's prebuilt riscv64
> packages install in seconds — the right tool for the hardware.

## Hardware

StarFive **VisionFive 2** — JH7110 SoC (quad SiFive U74, `RV64GC`, 1.5 GHz), 2/4/**8 GB**
LPDDR4. Get the 8 GB if you can. Boot from **NVMe (M.2)** or **eMMC**, not microSD — SD
is slow and wears out on a board this class.

**The GPU is a trap, and we sidestep it.** The VF2's Imagination BXE GPU has no clean
open driver. This setup uses X11 on the **software/`fbdev`/modesetting** path — no 3D,
no compositing, which dwm-class WMs + a terminal don't need. Don't install `picom`.

## 1. Base install (board-specific — do this first)

Alpine has no turnkey VF2 image, so getting the *base* booting is the fiddly part and
depends on your kernel/U-Boot choices. The shape of it:

1. **U-Boot / SPL** — flash a recent U-Boot to the SPI flash or SD per StarFive's
   docs (their `Tools`/VF2 U-Boot updater). This is the main first-day hurdle.
2. **Kernel + device tree** — HDMI display needs the JH7110 DRM driver, which is in
   **mainline ≥ 6.6**. Use a recent mainline kernel (cleaner) or StarFive's vendor
   fork (more peripheral coverage). Match it with the VF2 `.dtb`.
3. **Alpine rootfs** — put an Alpine **riscv64** (edge) rootfs on the NVMe/eMMC, then
   run `setup-alpine` for the base (hostname, network, users, `apk` mirror) and
   `setup-disk` to install it properly. Enable the **community** repo.

Cross-check the current StarFive VF2 + Alpine-riscv wiki pages for exact U-Boot/kernel
versions — they move fast.

## 2. Desktop (one script, all binary)

Once Alpine boots and you're at a root shell, clone this repo and run:

```sh
apk add git
git clone https://github.com/legendarymsr/legenddots
cd legenddots/alpine
TARGET_USER=legend KEYMAP=se ./setup.sh
```

`setup.sh` enables the community repo, `apk add`s the whole stack (**no compilation**),
creates your user, and drops the runtime dotfiles:

| thing | package | config (runtime) |
|-------|---------|------------------|
| **bspwm** + **sxhkd** | `bspwm sxhkd` | `~/.config/bspwm/bspwmrc`, `~/.config/sxhkd/sxhkdrc` |
| **xterm** | `xterm` | `~/.Xresources` (Tokyo Night — st's `config.h` as a dotfile) |
| **bemenu** | `bemenu` | dmenu-alike, themed by launch flags at runtime (no config.h) |
| **vis** | `vis` | `~/.config/vis/visrc.lua` + Tokyo Night theme (reused from `suckless/`) |
| **lynx** | `lynx` | — |
| **vi** (busybox) | (base) | `$EXINIT` in `~/.profile` |
| **Xorg** | `xorg-server xinit xf86-input-libinput xf86-video-fbdev` | `~/.xinitrc` → `exec bspwm` |

Then log in as your user and:

```sh
startx
```

**Keys** (Super = mod): `Return` xterm · `p` bemenu · `w` lynx · `e` vis · `q`/`shift+q`
close/kill · `{1-5}` desktops · `{h,j,k,l}` focus · `t`/`f` tiled/fullscreen · `shift+r`
reload bspwm · `shift+Escape` quit · `Escape` reload sxhkd.

## Notes

- **No compiling, ever.** Tweaks are dotfile edits: colors in `~/.Xresources`
  (`xrdb -merge ~/.Xresources` to reload), binds in `sxhkdrc` (`super+Escape` reloads).
- The **Tokyo Night** palette matches the rest of legenddots (st/dwm/Termux) — same
  colors, delivered at runtime instead of baked into a binary.
- **vis** uses the same name-based Tokyo Night theme as Termux, so it renders through
  xterm's palette and works regardless of vis's color-depth support.
- Want a status bar? `apk add lemonbar` (binary) and launch it from `bspwmrc` — kept
  out by default to stay minimal.
