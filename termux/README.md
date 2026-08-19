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
| `Alt+F1` | cycle focus between windows |
| `Alt+Escape` | quit the compositor |
| `Alt + left-drag` | move a window |
| `Alt + right-drag` | resize a window |

Change the terminal with `POCKETWL_TERMINAL=st bash start`, or the launcher with
`POCKETWL_LAUNCHER=wofi`, or edit `start`.

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

---

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
2. **May build from source.** If Guix has no aarch64 *substitute* (prebuilt
   binary) for icecat, it compiles it — a Firefox-class build, hours long. A
   device with lots of RAM handles it; time is the cost. Check substitute
   availability with `guix weather icecat` before committing.
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

Setup also drops a **`firefox` command** into Termux's `$PREFIX/bin`, so it shows
up in **rofi** (`Alt+D`, `-show run`) and the fzf `launcher` — picking it runs
`firefox.sh launch`. From a terminal inside pocketwl you can also just type
`firefox`.

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

pocketwl is deliberately a *stacking* compositor with no tiling, bar, or config
file — the tinywl skeleton. Natural next steps, all in `pocketwl.c`:

- **Tiling**: on `xdg_toplevel_map`, compute a layout over `server->toplevels`
  and `wlr_scene_node_set_position` / `wlr_xdg_toplevel_set_size` each window
  (mirror niri/sway's column idea).
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
