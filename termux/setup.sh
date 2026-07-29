#!/usr/bin/env bash
# pocketwl — install native Termux dependencies and build the compositor.
# Run inside Termux (not proot):  bash ~/legenddots/termux/setup.sh
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ":: Enabling the Termux x11-repo (wlroots/wayland/foot live there)..."
# GUI/Wayland packages are NOT in the default Termux repo — they're in x11-repo,
# which must be enabled before any of them can be located.
pkg install -y x11-repo

echo ":: Updating Termux packages..."
pkg update -y

echo ":: Installing build + runtime dependencies..."
# wlroots            — the compositor library pocketwl is built on
# wayland            — the Wayland server library (ships wayland-scanner too)
# wayland-protocols  — protocol XML (build dep of the stack)
# libxkbcommon       — keymap handling
# clang, make, pkg-config — toolchain
# termux-x11-nightly — the `termux-x11` launcher (the X server itself is the APK)
# foot               — a Wayland terminal to launch from the compositor
# NOTE: 'wayland-scanner' is NOT a separate package — it comes with 'wayland'.
pkg install -y \
    wlroots wayland wayland-protocols \
    libxkbcommon pkg-config clang make \
    termux-x11-nightly foot

echo ":: Building pocketwl..."
make -C "$DIR" clean
make -C "$DIR"

cat <<EOF

:: Done. Built: $DIR/pocketwl

Next:
  1. Install the *Termux:X11* app (the X server) from F-Droid or
     github.com/termux/termux-x11 — the 'termux-x11-nightly' package above only
     provides the launcher command, not the display server.
  2. Launch the desktop:
        bash $DIR/start

Keys inside pocketwl (modifier = Alt):
  Alt+Return  terminal      Alt+F1  cycle windows      Alt+Escape  quit
  Alt + drag  move/resize windows
EOF
