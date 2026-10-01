# pocketwl — a pocket Wayland compositor for Android/Termux

A minimal, from-scratch [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots)
Wayland compositor (~800 lines of C, derived from wlroots' reference *tinywl*)
that runs on **native Termux** and displays **nested inside Termux:X11** on
unrooted Android.

It's a real stacking compositor: xdg-shell windows, cursor, keyboard input,
window focus, and Alt-drag move/resize. Small enough to read in one sitting,
which is the point — it's a starting point you own, not a black box.

---

## How it works (and why nested X11)

Unrooted Android gives userspace **no DRM/KMS access**, so a Wayland compositor
can't drive the display directly the way it would on a Linux PC. The standard
workaround:

- **Termux:X11** is an Android app that provides an X server backed by the
  device's screen.
- wlroots has an **X11 backend**: when `DISPLAY` is set, `wlr_backend_autocreate`
  makes the compositor render into an X11 window instead of a DRM device.
- So pocketwl runs *inside* Termux:X11 — you get a Wayland compositor whose
  output is an X11 window shown by the Termux:X11 app. Wayland clients (foot,
  etc.) connect to pocketwl over `WAYLAND_DISPLAY`; pocketwl paints them into
  the X11 window; Termux:X11 puts that on screen.

```
Wayland apps ──WAYLAND_DISPLAY──▶ pocketwl ──X11 backend──▶ Termux:X11 ──▶ screen
```

Rooted devices could skip Termux:X11 and let wlroots use DRM directly — that's a
different build (see "Rooted" below).

---

## Prerequisites

1. **Termux** (from F-Droid — *not* the outdated Play Store build).
2. **Termux:X11 app** — the X server. Install the APK from F-Droid or
   [github.com/termux/termux-x11](https://github.com/termux/termux-x11). The
   `termux-x11-nightly` Termux *package* only provides the `termux-x11` launcher
   command; the APK is the actual display server and must be installed separately.

---

## Build & run

```sh
# in Termux
pkg install git
git clone https://github.com/legendarymsr/legenddots ~/legenddots
bash ~/legenddots/termux/setup.sh     # installs deps, builds ./pocketwl
bash ~/legenddots/termux/start        # starts Termux:X11 + pocketwl
```

> **`E: Unable to locate package wlroots` / `foot`?** Those live in Termux's
> **x11-repo**, not the default repo — `setup.sh` enables it for you
> (`pkg install x11-repo && pkg update`). Run that first if installing by hand.
>
> **`Unable to locate package wayland` / `wayland-protocols`?** Don't install
> those by name — the package names vary across Termux mirrors. `wlroots`
> *depends* on Wayland, so `pkg install wlroots` pulls the right library (headers
> + `wayland-scanner` included) automatically. If even `wlroots` won't resolve,
> your mirror is stale: run `termux-change-repo`, pick a fresh mirror, then retry.

Then switch to the **Termux:X11 app** to see the compositor. A terminal (`foot`)
opens automatically.

### Keybindings (modifier = Alt)

| Key | Action |
|-----|--------|
| `Alt+Return` | spawn a terminal (`$POCKETWL_TERMINAL`, default `foot`) |
| `Alt+D` | app launcher (`$POCKETWL_LAUNCHER`, default `fuzzel`) |
| `Alt+h/j/k/l` | **focus the tile left / down / up / right** |
| `Alt+Ctrl+h/j/k/l` | **move (swap) the focused tile** in that direction |
| `Alt+Shift+H/J/K/L` | same move, for keyboards that have a Shift key |
| `Alt+Left` / `Alt+Right` | shrink / grow the master column |
| `Alt+t` | toggle tiling on/off |
| `Alt+F1` | cycle focus between windows |
| `Alt+Escape` | quit the compositor |
| `Alt + left-drag` | move a window (when tiling is off) |
| `Alt + right-drag` | resize a window (when tiling is off) |

Change the terminal with `POCKETWL_TERMINAL=st bash start`, or the launcher with
`POCKETWL_LAUNCHER=wofi`, or edit `start`.

### Tiling

Windows tile automatically in a **master–stack** layout (like dwm): the first
window is the *master*, taking the left half; each new window joins the *stack*
that splits the right half into equal rows. One window fills the screen. Move
focus between tiles with **`Alt+h/j/k/l`** (directional — nearest window in that
direction) and **move/swap** the focused tile with **`Alt+Ctrl+h/j/k/l`** (or
`Alt+Shift+H/J/K/L` if your keyboard has Shift — Termux:X11's extra-keys row has
Ctrl+Alt but usually no Shift; swapping into the master slot promotes it). Resize
the master with
`Alt+Left`/`Alt+Right`, and toggle tiling off with `Alt+t` (then windows float and
`Alt+drag` moves/resizes them). A new window becomes the master; close one and the
rest re-tile to fill the space.

### Touch

pocketwl maps **touch onto the pointer**: a tap warps the cursor and left-clicks,
a drag moves it. That makes finger input work with pointer-only apps (foot,
fuzzel) — the practical win on a phone. (Real multitouch would need
`wlr_seat_touch_*`, but almost nothing on this stack uses it.)

### Session identity

The compositor exports `XDG_CURRENT_DESKTOP=pocketwl` and
`XDG_SESSION_TYPE=wayland`, so apps that branch on the session (and fastfetch's
WM/DE detection) can identify it — otherwise there's no Wayland protocol to ask
"which compositor?".

### Window sizing / filling the screen

Two things had to line up for pocketwl to actually fill the phone screen:

1. **The output.** wlroots' X11 backend defaults its window to a fixed
   **1024×768**, so the compositor showed up letterboxed in a corner of
   Termux:X11. pocketwl now reads the real screen size off the X server (via
   `xcb`, the same `DISPLAY` the backend uses) and sets the output to a **custom
   mode** matching it — so the compositor covers the whole Termux:X11 canvas.
   (On the rooted DRM path there's no `DISPLAY`, so it falls back to the panel's
   preferred mode.)
2. **The windows.** On a phone, tiny floating windows are useless, so **every
   window opens filling the output** (sized on first commit, not left at the
   client's default), and explicit **maximize / fullscreen requests** (e.g.
   Firefox's `F11`) are honored — resized to cover the output, client told it's
   fullscreen/maximized. No bars or gaps, so "maximized" and "fullscreen" both
   just mean "the whole screen".

---

## Editor & tmux (dotfiles on the phone)

The repo is already cloned at `~/legenddots` (the build step above). One script
pulls it and symlinks all the phone configs — no hand-copying individual `ln`
lines, and it **skips any target missing from the clone so you never get a
dangling link**:

```sh
pkg install zsh neovim tmux screen vis git
bash ~/legenddots/termux/dotfiles.sh
```

`dotfiles.sh` links (creating config dirs, backing up any real file in the way):

| repo file | → linked to |
|-----------|-------------|
| `.zshrc` | `~/.zshrc` — zsh config (script removes any existing one, links this, sets zsh default) |
| `init.lua` | `~/.config/nvim/init.lua` — same as desktop (Mason/LSP self-skips on Termux) |
| `tmux.conf` | `~/.config/tmux/tmux.conf` — tmux 3.1+ reads it there |
| `suckless/screen/screenrc` | `~/.screenrc` — home dir, not `~/.config` |
| `suckless/vis/visrc.lua` | `~/.config/vis/visrc.lua` — vis config (Lua, no VimL) |
| `suckless/vis/themes/tokyonight.lua` | `~/.config/vis/themes/tokyonight.lua` — Tokyo Night |
| `suckless/vi/exrc` | `~/.exrc` — POSIX vi baseline (nvi / traditional vi) |
| `termux/colors.properties` | `~/.termux/colors.properties` — Tokyo Night terminal (auto `termux-reload-settings`) |

Re-run it any time to update — it does the `git pull` for you, and because the
links are stable it's idempotent.

**Termux specifics** (handled automatically — `tmux.conf` branches on `$TERMUX_VERSION`):

- **terminfo** — Termux often ships no `tmux-256color` entry, which makes tmux
  refuse to start. The config falls back to `screen-256color` on Termux (always
  present) and keeps `tmux-256color` on the desktop. Truecolor still works via the
  `*:RGB` override.
- **prefix** — `Alt+Space`, same as desktop. Termux's extra-keys row has `Alt`
  (swipe it up if hidden).
- **window keys** — the desktop's no-prefix `Alt+h`/`Alt+l` window cycle is
  disabled on Termux, because **pocketwl claims `Alt+hjkl`** for tile focus. Use
  the prefix there instead: `Alt+Space` then `n` / `p` (next / prev window).

To land straight in tmux under pocketwl, run `tmux` in the `Alt+Return` terminal,
or set `POCKETWL_TERMINAL='foot -e tmux' bash start` so every terminal opens into it.

### Editors on the phone

**vis** — modal (vi keys) + Plan 9 structural regex, configured in **Lua** (no
Vimscript). It's in Termux's main repo, and `dotfiles.sh` links `~/.config/vis/visrc.lua`
plus the Tokyo Night theme:

```sh
pkg install vis
```

**vi baseline** — `dotfiles.sh` also links `~/.exrc` (`suckless/vi/exrc`), the POSIX
`set`s that `nvi` / traditional vi honour when vis isn't around (Termux's `vi` is busybox,
which uses `$EXINIT` rather than `~/.exrc`, so `vis` is the real editor here). `nvim` reads
`init.lua`. **vim was dropped** — Vimscript is a config DSL (see `suckless/README.md`). To
type `vi` for vis: `ln -sfn "$PREFIX/bin/vis" "$PREFIX/bin/vi"`.

---

## GNU Guix in a proot (`guix-proot.sh`)

A reusable Guix host on your phone. Termux can't run Guix natively (no root, no
user namespaces, no `/gnu/store`), so this layers Guix on a **proot-distro**
base (Debian by default) and runs `guix-daemon --disable-chroot`, which is what
proot needs. It's the same Guix that `icecat.sh` uses — set it up once, then
`guix install` anything.

```sh
bash ~/legenddots/termux/guix-proot.sh            # set up the proot + Guix
bash ~/legenddots/termux/guix-proot.sh pull       # update Guix
bash ~/legenddots/termux/guix-proot.sh guix install hello
bash ~/legenddots/termux/guix-proot.sh weather hello   # prebuilt binary available?
bash ~/legenddots/termux/guix-proot.sh login      # a shell inside it
bash ~/legenddots/termux/guix-proot.sh daemon     # (re)start the daemon
bash ~/legenddots/termux/guix-proot.sh doctor     # check the whole setup
```

Start with **`doctor`** if anything's off — it reports guix version, whether the
daemon is up, that the JIT is disabled, and which substitute servers are
authorized.

Base distro via `GUIX_DISTRO` (default `debian`). It's tuned for Termux:

- **Bordeaux substitutes** — it authorizes *both* `ci.guix.gnu.org` and
  `bordeaux.guix.gnu.org` and points the daemon at both. Bordeaux builds far more
  aarch64, so most installs download a binary instead of compiling for hours.
  (A package it still lacks builds from source — check `guix weather PKG` first.)
- **`PROOT_NO_SECCOMP=1`** — proot's seccomp emulation trips Guix daemon syscalls;
  disabling it is slower but much more reliable.
- **No JIT** — `GUILE_JIT_THRESHOLD=-1` for every op (client + daemon); Guile's
  JIT crashes under proot, which is the usual "`guix pull` kills Termux".
- **Daemon tuned for proot** — `--disable-chroot --disable-deduplication` (store
  hardlink dedup misbehaves on proot's VFS), and it *waits for the daemon socket*
  before running, so the first command doesn't race a half-started daemon.
- **Locales** — sets `GUIX_LOCPATH` and installs `glibc-locales` so UTF-8 works
  and Guix stops spamming locale warnings.

Still honest: Guix-in-proot is **fragile** (the daemon only gets proot's fake
root/namespaces). If setup wedges, finish by hand in `guix-proot.sh login`.

### If `guix pull` (or a build) crashes/kills Termux

Two Android things, not Guix bugs:

1. **Phantom-process killer (the usual cause).** Android 12+ silently kills apps
   that spawn many child processes — and proot + guix-daemon + a compile spawn a
   *lot*. Termux just vanishes mid-build.
   - **If your ROM exposes the toggle** (Nothing OS 5 and other recent Android
     builds have **"Disable child process restrictions"** in Developer options;
     GrapheneOS has it per-app) — just flip it. No adb needed. ← easiest.
   - **Otherwise,** disable it over **adb** (from a PC or wireless adb; survives
     reboot), then reboot:
     ```sh
     adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"
     adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
     adb shell settings put global settings_enable_monitor_phantom_procs false
     ```
   This is the single biggest fix.
2. **Guile JIT under proot (the real cause on a RAM-rich phone).** Guile's JIT
   emits machine code / executable mmaps that proot's emulation mishandles, so
   heavy Guile work like `guix pull` crashes (SIGILL/SIGSEGV) and takes Termux
   with it — *not* an out-of-memory thing on a 12/16 GB device. `guix-proot.sh`
   now exports **`GUILE_JIT_THRESHOLD=-1`** for every guix op (client and daemon)
   to turn the JIT off; costs a little speed, buys stability. Combined with
   `PROOT_NO_SECCOMP=1`, that's the pair that keeps proot from dying.
3. **Out-of-memory** (only on low-RAM devices). If you're tight on RAM, cap
   parallelism: `GUIX_CORES=1 GUIX_MAX_JOBS=1 guix-proot.sh pull` (or `… guix
   install PKG`). The script also holds `termux-wake-lock`. On 12 GB+ you won't
   need this.

### "substitutes … 0.0%" on everything, then it crashes

Two things are happening:

1. **You haven't pulled.** The binary-tarball Guix is pinned to an old release
   commit the build farms no longer serve, so *every* package reads `0.0%` and
   Guix falls back to **building from source** — and a source build inside proot
   crashes Termux. Fix: `guix-proot.sh pull` (setup now does this automatically).
   After pulling you're on a recent commit Bordeaux has aarch64 binaries for, and
   installs download instead of building.
2. **Source builds don't really work in proot anyway.** proot can't give the build
   daemon real namespaces, so a big build tends to crash rather than finish. Treat
   this proot as **substitute-only**: install things that have a prebuilt aarch64
   binary (`guix weather PKG` → >0%), and avoid anything that would compile.

**IceCat is the main casualty.** It's a Firefox-class package with essentially no
aarch64 substitute, so it can't be built here — `icecat.sh` now checks `weather`
and refuses rather than crash. For libre browsing on-device use **lynx** or
**w3m** (text, substituted) or Emacs **eww**; a GUI libre browser via Guix-in-proot
isn't realistic on aarch64 today.

Prefer substitutes over `guix pull` where you can — the installer's Guix already
has a package set; you only need to pull to *update* it. `guix weather PKG` first
so you're downloading binaries, not compiling.

## Genuine GNU IceCat via Guix (`icecat.sh`)

A libre desktop browser running inside pocketwl. **Read this first — it's the
honest situation, not a one-liner anyone can promise:**

- **GNU IceCat has no aarch64 binary.** The FSF ships it x86_64-only; Debian,
  Ubuntu, and Termux don't package it at all.
- **GNU Guix does** package genuine IceCat and supports aarch64 — and Guix's
  `icecat` is the same FSDG-libre browser regardless of the host distro. So the
  genuine-libre browser comes from **Guix**, layered on a proot.
- **Trisquel** would be the ideal fully-libre host, but proot-distro has no
  built-in Trisquel and Trisquel publishes no official arm64 *proot rootfs*. So
  `icecat.sh` defaults to a **Debian** proot as the Guix host (reliable) and lets
  you swap in Trisquel (below). Guix's icecat is genuine libre either way.

```sh
bash ~/legenddots/termux/icecat.sh          # set up proot + Guix + install icecat
# then, from a terminal INSIDE pocketwl:
bash ~/legenddots/termux/icecat.sh launch    # run IceCat, displayed in pocketwl
```

### The honest caveats

1. **Guix in a proot is fragile.** Guix's build daemon wants user namespaces /
   root that proot only fakes. `icecat.sh` runs the standard steps (installer,
   `guix-daemon --disable-chroot`, `guix pull`, `guix install icecat`) but can't
   guarantee first-run success. If it fails, finish by hand inside the proot:
   ```sh
   proot-distro login debian
   # start the daemon if it isn't running:
   guix-daemon --build-users-group=guixbuild --disable-chroot &
   guix pull
   guix install icecat
   ```
2. **Usually no aarch64 substitute → it won't install here.** IceCat is a
   Firefox-class build and the farms rarely build it for aarch64, so there's no
   binary to download — and compiling it inside proot crashes Termux. `icecat.sh`
   now runs `guix weather icecat` first and **refuses** if it's 0% (override with
   `ICECAT_FORCE=1`, not recommended). On aarch64 this effectively means IceCat is
   off the table on-device; use lynx/w3m/eww instead.
3. **Software rendering.** IceCat renders through pocketwl's llvmpipe path —
   usable for reading, not smooth for video.

### Using Trisquel as the host instead

Guix's icecat is already FSDG-libre, but if you want the base distro libre too:
register a Trisquel arm64 rootfs as a proot-distro plugin, then point the script
at it.

```sh
# 1. Write a proot-distro plugin (needs a Trisquel arm64 rootfs tarball URL):
cat > $PREFIX/etc/proot-distro/trisquel.sh <<'PLUGIN'
DISTRO_NAME="Trisquel GNU/Linux-libre"
TARBALL_URL['aarch64']="<url to a trisquel arm64 rootfs .tar.xz>"
TARBALL_SHA256['aarch64']="<sha256>"
PLUGIN
# 2. Use it:
ICECAT_DISTRO=trisquel bash ~/legenddots/termux/icecat.sh
```

Trisquel doesn't publish a ready proot tarball, so you supply one (e.g.
debootstrap Trisquel "aramo" arm64, or repack a Trisquel arm64 image). The Guix +
IceCat steps are identical on top.

### If you just want a working libre browser today (`firefox.sh`)

Guix-from-source-in-a-proot is the purist path and can be a yak-shave. The
reliable free-software browser that works now is Debian's `firefox-esr` (DFSG-free,
though not the IceCat brand) — it ships a prebuilt aarch64 binary and installs in
one apt command. `firefox.sh` does the whole thing (Debian proot + install), and
its `launch` subcommand runs it as a Wayland client in pocketwl, exactly like
`icecat.sh`:

```sh
bash ~/legenddots/termux/firefox.sh          # set up Debian proot + firefox-esr
# then, from a terminal INSIDE pocketwl:
bash ~/legenddots/termux/firefox.sh launch    # run Firefox ESR, displayed in pocketwl
```

Setup also drops a **`firefox-esr` command** into Termux's `$PREFIX/bin`, so it
shows up in **rofi** (`Alt+D`, `-show run`) and the fzf `launcher` — picking it
runs `firefox.sh launch`. From a terminal inside pocketwl you can also just type
`firefox-esr`. (Termux has no native Firefox package; this command is only that
wrapper. Remove it with `rm "$PREFIX/bin/firefox-esr"`.)

Override the base distro with `FIREFOX_DISTRO=...` if you keep firefox-esr in a
different proot. Same software-rendering caveat as IceCat: fine for reading, not
for video.

---

## The wlroots-version caveat (important)

**wlroots does not promise a stable API** — struct fields and function
signatures change between minor releases. `pocketwl.c` targets the **wlroots 0.18**
API. Check what Termux ships:

```sh
pkg show wlroots | grep -i version
pkg-config --modversion wlroots-0.18 2>/dev/null || pkg-config --list-all | grep wlroots
```

- **0.18** → builds as-is.
- **0.17 / 0.19** → the `Makefile` auto-detects the pkg-config name, but the
  *source* may need small edits (a renamed field, a changed function arg). The
  compiler errors point straight at them; the upstream `tinywl.c` for your exact
  version is the reference to diff against
  ([wlroots tinywl](https://gitlab.freedesktop.org/wlroots/wlroots/-/tree/master/tinywl)).

This is the same honesty as the rest of this repo's from-scratch builds: it's a
correct, complete compositor for the version it targets, but a moving-target
dependency means a version bump can need a few lines of adjustment.

---

## Files

| File | What |
|------|------|
| `pocketwl.c` | the compositor (xdg-shell, cursor, keyboard, move/resize) |
| `Makefile` | builds against Termux's wlroots (auto-detects the pkg-config name) |
| `setup.sh` | installs Termux deps + builds |
| `start` | launches Termux:X11 and runs pocketwl nested in it |
| `icecat.sh` | sets up a proot + GNU Guix and installs genuine GNU IceCat (`launch` subcommand runs it in pocketwl) |
| `firefox.sh` | sets up a Debian proot and installs Firefox ESR — the reliable browser path (`launch` runs it in pocketwl) |

---

## Extending it

pocketwl now does master–stack **tiling** (see `tile()` in `pocketwl.c`) on top of
the tinywl skeleton — no bar or config file yet. Natural next steps, all in
`pocketwl.c`:

- **Swap/move windows**: promote the focused tile to master, or swap two tiles,
  by reordering `server->toplevels` and calling `tile()` (add an `Alt+Shift+hjkl`).
- **Workspaces**: multiple scene trees / toplevel lists, switched by a keybind.
- **Layouts**: add a monocle/columns layout and toggle it (extend `tile()`).
- **More keybindings**: extend `handle_keybinding()` — close window
  (`wlr_xdg_toplevel_send_close`), workspaces (multiple scene trees), app launcher.
- **Touch input**: Android is a touchscreen — handle `WLR_INPUT_DEVICE_TOUCH`
  in `server_new_input` and wire `wlr_seat_touch_notify_*` (the big win over
  plain tinywl for a phone).
- **On-screen bar**: a `wlr_scene_rect` / text via a layer-shell client.

---

## Rooted devices (alternative)

With root you can grant Termux access to `/dev/dri/*` and drop Termux:X11
entirely: run `start` without setting `DISPLAY` (so wlroots picks the DRM
backend), and `chmod`/`chown` the DRM nodes to your Termux uid. That's outside
this setup's scope, but pocketwl.c itself needs no changes — `wlr_backend_autocreate`
handles both backends. You'll want `seatd` (or root) for input device access.
