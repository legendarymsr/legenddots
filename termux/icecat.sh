#!/usr/bin/env bash
# =============================================================================
# Genuine GNU IceCat inside pocketwl — via a proot distro + GNU Guix.
#
# WHY THIS SHAPE (read this — it's the honest situation):
#   * GNU IceCat has NO aarch64 binary. The FSF ships it x86_64-only, and
#     Debian/Ubuntu/Termux don't package it at all.
#   * GNU GUIX, however, packages genuine IceCat and supports aarch64 — and
#     Guix's icecat is the SAME FSDG-libre browser regardless of the host
#     distro. So the genuine-libre browser comes from Guix, not from the base.
#   * TRISQUEL is the ideal fully-libre host, but proot-distro has no built-in
#     Trisquel and Trisquel publishes no official arm64 *proot rootfs*. So this
#     defaults to a Debian proot as the Guix host (reliable) and documents the
#     Trisquel swap (set TRISQUEL_ROOTFS_URL / drop in a proot-distro plugin).
#     Guix's icecat is genuine libre either way.
#
# HONEST WARNINGS:
#   * Guix's build daemon wants user namespaces / root that proot only fakes.
#     Guix inside a Termux proot is FRAGILE and may need manual fiddling; this
#     script does the standard steps but cannot guarantee first-run success.
#   * If Guix has no aarch64 *substitute* for icecat, it BUILDS FROM SOURCE
#     (Firefox-class — hours). Your device's RAM can handle it; time is the cost.
#   * IceCat renders through pocketwl's software (llvmpipe) path — usable, not fast.
#
# Usage:
#   bash ~/legenddots/termux/icecat.sh            # set everything up
#   bash ~/legenddots/termux/icecat.sh launch     # run IceCat inside pocketwl
# =============================================================================
set -u

DISTRO="${ICECAT_DISTRO:-debian}"   # base proot; override with a Trisquel plugin
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
  say "Launching IceCat in the $DISTRO proot (Wayland → pocketwl)..."
  # Bind the Termux runtime dir (with the wayland socket) into the proot and
  # point IceCat at it. --shared-tmp also exposes $PREFIX/tmp.
  exec proot-distro login "$DISTRO" --shared-tmp -- \
    env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$WL" \
        MOZ_ENABLE_WAYLAND=1 GDK_BACKEND=wayland \
        GUIX_PROFILE=/root/.guix-profile \
        bash -lc '. /root/.guix-profile/etc/profile 2>/dev/null; exec icecat'
fi

# ── setup ─────────────────────────────────────────────────────────────────────
say "Installing proot-distro..."
pkg install -y proot-distro || { warn "could not install proot-distro"; exit 1; }

if [[ -n "${TRISQUEL_ROOTFS_URL:-}" ]]; then
  say "TRISQUEL_ROOTFS_URL set — see README to register it as a proot-distro plugin,"
  say "then re-run with ICECAT_DISTRO=trisquel. Proceeding with '$DISTRO' for now."
fi

say "Installing the '$DISTRO' proot (the Guix host)..."
proot-distro install "$DISTRO" 2>/dev/null || say "  ($DISTRO already installed)"

say "Preparing the proot + installing GNU Guix (this is the fragile step)..."
proot-distro login "$DISTRO" --shared-tmp -- bash -lc '
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  # Guix installer deps + a few libs IceCat/GTK expect from the host.
  apt-get install -y wget xz-utils gpg guile-3.0-libs libgtk-3-0 \
    fonts-dejavu ca-certificates locales || true

  if ! command -v guix >/dev/null 2>&1; then
    echo ":: fetching the GNU Guix install script..."
    cd /root
    wget -q https://guix.gnu.org/install.sh -O guix-install.sh
    # Non-interactive; the installer sets up /gnu/store and guix-daemon.
    yes "" | bash guix-install.sh || \
      echo "!! Guix installer reported errors (expected in proot) — see README to finish by hand."
  fi

  # Start the daemon (proot has no init); background it.
  if command -v guix-daemon >/dev/null 2>&1; then
    guix-daemon --build-users-group=guixbuild --disable-chroot >/var/log/guix-daemon.log 2>&1 &
    sleep 3
  fi

  echo ":: guix pull + installing genuine GNU IceCat (may build from source)..."
  guix pull || echo "!! guix pull failed — see README"
  guix install icecat || echo "!! guix install icecat failed — see README (substitutes/daemon)"
' || warn "proot setup hit errors — see the notes above and libre/… no, termux/README.md"

cat <<EOF

:: Setup attempted. To run IceCat inside pocketwl:
     1. bash ~/legenddots/termux/start          # start pocketwl (open Termux:X11)
     2. from a terminal INSIDE pocketwl:
          bash ~/legenddots/termux/icecat.sh launch

If Guix or the icecat install failed above, that's the known proot/Guix
friction — see the "Genuine IceCat via Guix" section of termux/README.md for the
manual daemon/substitute steps. IceCat from Guix is genuine FSDG-libre software.
EOF
