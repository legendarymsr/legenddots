#!/usr/bin/env bash
# =============================================================================
# Firefox ESR inside pocketwl — via a Debian proot. The reliable browser path.
#
# WHY THIS EXISTS (vs icecat.sh):
#   * icecat.sh installs genuine GNU IceCat from Guix-in-a-proot — the purist
#     FSDG-libre path, but Guix's daemon fights proot and IceCat may build from
#     source for hours. It's the yak-shave path.
#   * Debian's firefox-esr is DFSG-free (not the IceCat brand, but free software),
#     ships a prebuilt aarch64 binary, and installs with one apt command. This is
#     the browser that works TODAY. It renders as a Wayland client straight into
#     pocketwl.
#
# NOTE ON RENDERING: Firefox draws through pocketwl's software (llvmpipe) path —
# fine for reading/browsing, not smooth for video.
#
# Usage:
#   bash ~/legenddots/termux/firefox.sh           # install firefox-esr in Debian
#   bash ~/legenddots/termux/firefox.sh launch     # run it inside pocketwl
# =============================================================================
set -u

DISTRO="${FIREFOX_DISTRO:-debian}"   # Debian ships the firefox-esr aarch64 build
say()  { echo ":: $*"; }
warn() { echo "!! $*" >&2; }

# ── launch subcommand ─────────────────────────────────────────────────────────
if [[ "${1:-}" == "launch" ]]; then
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-$PREFIX/tmp}}"
  WL="${WAYLAND_DISPLAY:-wayland-1}"
  if [[ ! -S "$XDG_RUNTIME_DIR/$WL" ]]; then
    warn "No Wayland socket at $XDG_RUNTIME_DIR/$WL — start pocketwl first (bash termux/start),"
    warn "then run this from a terminal *inside* pocketwl so WAYLAND_DISPLAY is set."
    exit 1
  fi
  say "Launching Firefox ESR in the $DISTRO proot (Wayland → pocketwl)..."
  # Bind the Termux runtime dir (holding the wayland socket) into the proot and
  # point Firefox at it. --shared-tmp also exposes $PREFIX/tmp.
  exec proot-distro login "$DISTRO" --shared-tmp -- \
    env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$WL" \
        MOZ_ENABLE_WAYLAND=1 GDK_BACKEND=wayland \
        bash -lc 'exec dbus-run-session firefox-esr'
fi

# ── setup ─────────────────────────────────────────────────────────────────────
say "Installing proot-distro..."
pkg install -y proot-distro || { warn "could not install proot-distro"; exit 1; }

say "Installing the '$DISTRO' proot..."
proot-distro install "$DISTRO" 2>/dev/null || say "  ($DISTRO already installed)"

say "Installing firefox-esr inside the proot..."
proot-distro login "$DISTRO" --shared-tmp -- bash -lc '
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  # firefox-esr + the fonts/certs a fresh Debian rootfs is missing.
  apt-get install -y firefox-esr ca-certificates fonts-dejavu locales dbus-x11
' || warn "proot setup hit errors — see termux/README.md."

cat <<EOF

:: Done. To run Firefox ESR inside pocketwl:
     1. bash ~/legenddots/termux/start           # start pocketwl (open Termux:X11)
     2. from a terminal INSIDE pocketwl:
          bash ~/legenddots/termux/firefox.sh launch

firefox-esr is DFSG-free software with a prebuilt aarch64 binary, so this path
is quick and reliable. For the genuine GNU IceCat brand instead, see icecat.sh
(the Guix path) and the "Genuine IceCat via Guix" section of termux/README.md.
EOF
