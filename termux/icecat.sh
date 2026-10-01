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
# The Guix host (proot-distro + Guix + daemon + Bordeaux substitutes + locales +
# PROOT_NO_SECCOMP) is handled by guix-proot.sh so IceCat gets all those fixes.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${TRISQUEL_ROOTFS_URL:-}" ]]; then
  say "TRISQUEL_ROOTFS_URL set — register it as a proot-distro plugin (see README),"
  say "then re-run with ICECAT_DISTRO=trisquel. Using '$DISTRO' for now."
fi

say "Setting up the Guix host via guix-proot.sh (base: $DISTRO)..."
GUIX_DISTRO="$DISTRO" bash "$SELF_DIR/guix-proot.sh" \
  || warn "guix-proot setup hit errors — see termux/README.md (proot/Guix friction)."

# IceCat/GTK want a few host libs for the Wayland launch later.
proot-distro login "$DISTRO" --shared-tmp -- bash -lc \
  'export DEBIAN_FRONTEND=noninteractive; apt-get install -y libgtk-3-0 fonts-dejavu >/dev/null 2>&1 || true' || true

say "Installing genuine GNU IceCat (downloads a binary if Bordeaux has it; else builds)..."
GUIX_DISTRO="$DISTRO" bash "$SELF_DIR/guix-proot.sh" guix install icecat \
  || warn "guix install icecat failed — check 'bash guix-proot.sh guix weather icecat', see README."

cat <<EOF

:: Setup attempted. To run IceCat inside pocketwl:
     1. bash ~/legenddots/termux/start          # start pocketwl (open Termux:X11)
     2. from a terminal INSIDE pocketwl:
          bash ~/legenddots/termux/icecat.sh launch

Tip: 'bash ~/legenddots/termux/guix-proot.sh guix weather icecat' shows whether a
prebuilt aarch64 binary exists (Bordeaux) before you commit to a source build.
If Guix friction bit, see the "Genuine IceCat via Guix" section of termux/README.md.
IceCat from Guix is genuine FSDG-libre software.
EOF
