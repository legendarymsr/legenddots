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

Then switch to the **Termux:X11 app** to see the compositor. A terminal (`foot`)
opens automatically.

### Keybindings (modifier = Alt)

| Key | Action |
|-----|--------|
| `Alt+Return` | spawn a terminal (`$POCKETWL_TERMINAL`, default `foot`) |
| `Alt+F1` | cycle focus between windows |
| `Alt+Escape` | quit the compositor |
| `Alt + left-drag` | move a window |
| `Alt + right-drag` | resize a window |

Change the terminal with `POCKETWL_TERMINAL=st bash start`, or edit `start`.

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
