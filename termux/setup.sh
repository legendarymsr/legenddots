#!/usr/bin/env bash
# pocketwl — install native Termux dependencies and build the compositor.
# Run inside Termux (not proot):  bash ~/legenddots/termux/setup.sh
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say()  { echo ":: $*"; }
warn() { echo "!! $*" >&2; }

# ── 1. Repos ──────────────────────────────────────────────────────────────────
# GUI/Wayland packages live in x11-repo, not the default Termux repo.
say "Enabling x11-repo (wlroots/foot live there)..."
pkg install -y x11-repo >/dev/null 2>&1 || true
say "Refreshing package lists..."
pkg update -y >/dev/null 2>&1 || true

# Upgrade everything to matching versions. Termux packages share ABIs (protobuf
# ↔ abseil, etc.); installing new packages against a half-upgraded system causes
# runtime "cannot locate symbol" linker errors. Keeping the set in sync avoids it.
say "Upgrading installed packages to matching versions (avoids ABI mismatches)..."
pkg upgrade -y >/dev/null 2>&1 || true

# ── 2. Toolchain + terminal + launcher (never blocks on Wayland lib names) ────
say "Installing toolchain + terminal + Termux:X11 launcher..."
pkg install -y clang make pkg-config libxkbcommon foot termux-x11-nightly \
  || warn "some of these failed — continuing; wlroots is the critical one below"

# A Wayland launcher for Alt+D. Which one is packaged varies across Termux
# mirrors (fuzzel is often absent), so install the first that resolves.
say "Installing a Wayland launcher (for Alt+D)..."
for l in fuzzel wofi tofi bemenu; do
  pkg install -y "$l" >/dev/null 2>&1 && { echo "   + $l"; break; }
done
command -v fuzzel wofi tofi bemenu-run >/dev/null 2>&1 \
  || warn "   no launcher installed — Alt+D stays inert until you 'pkg install wofi'"

# X11 dev/protocol packages: wlroots is built with the X11 backend (needed to
# nest inside Termux:X11), so its pkg-config graph Requires xproto/xcb/x11/etc.
# Termux installs wlroots's *runtime* X libs but not these dev/proto .pc files,
# and a single missing one makes `pkg-config --cflags wlroots` fail silently
# (no -I paths → "wlr/backend.h not found"). xorgproto (→ xproto.pc) is the key
# one. Install them ONE AT A TIME so a single unavailable name doesn't abort the
# whole batch (apt is all-or-nothing per command).
say "Installing X11 dev/protocol packages (wlroots pkg-config deps)..."
# wayland-protocols provides xdg-shell.xml, which we scan into a header (wlroots'
# own wlr_xdg_shell.h includes the generated "xdg-shell-protocol.h").
for p in xorgproto libxcb libx11 libxau libxdmcp libdrm wayland-protocols; do
  pkg install -y "$p" >/dev/null 2>&1 && echo "   + $p" \
    || warn "   (could not install $p — may be unavailable under that name)"
done

# wayland-scanner ships with the 'wayland' package (pulled in by wlroots).
if ! command -v wayland-scanner >/dev/null 2>&1; then
  pkg install -y wayland >/dev/null 2>&1 || true
fi

# ── 3. wlroots (pulls the correct Wayland lib transitively) ───────────────────
say "Installing wlroots..."
if ! pkg install -y wlroots; then
  warn "Could not install wlroots. Your mirror may be stale."
  warn "Fix: run 'termux-change-repo', pick a different mirror, then re-run this."
  exit 1
fi

# ── 4. Verify the dev files are actually present ──────────────────────────────
WLROOTS_PC=$(pkg-config --list-all 2>/dev/null | awk '/^wlroots/{print $1; exit}')
if [[ -z "$WLROOTS_PC" ]]; then
  warn "wlroots installed but no wlroots*.pc found in pkg-config's path."
  warn "Contents of \$PREFIX/lib/pkgconfig:"
  ls "$PREFIX/lib/pkgconfig" | grep -i wl >&2 || true
  warn "Try: termux-change-repo → fresh mirror → re-run."
  exit 1
fi
if ! pkg-config --exists wayland-server; then
  warn "wayland-server pkg-config missing (should have come in with wlroots)."
  warn "Try: termux-change-repo → fresh mirror → re-run."
  exit 1
fi

WLROOTS_VER=$(pkg-config --modversion "$WLROOTS_PC" 2>/dev/null || echo "?")
say "Found $WLROOTS_PC (version $WLROOTS_VER)"
case "$WLROOTS_VER" in
  0.18*) : ;;  # exactly what pocketwl.c targets
  *) warn "pocketwl.c targets the wlroots 0.18 API; you have $WLROOTS_VER."
     warn "It may still build, or the compiler may flag a few renamed symbols."
     warn "If it errors, diff pocketwl.c against upstream tinywl for $WLROOTS_VER"
     warn "  (gitlab.freedesktop.org/wlroots/wlroots, matching tag). See README." ;;
esac

# ── 4b. Confirm wlroots's full pkg-config graph resolves ─────────────────────
if ! pkg-config --cflags "$WLROOTS_PC" >/dev/null 2>&1; then
  warn "pkg-config can't resolve $WLROOTS_PC's dependency graph. Missing .pc:"
  pkg-config --cflags "$WLROOTS_PC" 2>&1 | grep -i "not found" >&2 || true
  warn "Install the package that provides the named .pc (e.g. xproto → xorgproto,"
  warn "xcb-* → libxcb, xrender → libxrender) and re-run."
  exit 1
fi

# ── 4c. Confirm we can generate the xdg-shell protocol header ────────────────
XML_DIR=$(pkg-config --variable=pkgdatadir wayland-protocols 2>/dev/null)
XML_DIR="${XML_DIR:-$PREFIX/share/wayland-protocols}"
if [[ ! -f "$XML_DIR/stable/xdg-shell/xdg-shell.xml" ]]; then
  warn "xdg-shell.xml not found under $XML_DIR — install 'wayland-protocols':"
  warn "    pkg install wayland-protocols"
  warn "(wlroots' wlr_xdg_shell.h needs the generated xdg-shell-protocol.h.)"
  exit 1
fi

# ── 5. Build ──────────────────────────────────────────────────────────────────
say "Building pocketwl..."
make -C "$DIR" clean >/dev/null 2>&1 || true
if make -C "$DIR" pocketwl; then
  cat <<EOF

:: Success — built: $DIR/pocketwl

Next:
  1. Install the *Termux:X11* app (the X server) from F-Droid or
     github.com/termux/termux-x11 — the package above is only the launcher.
  2. Launch:  bash $DIR/start   (then open the Termux:X11 app)

Keys (modifier = Alt): Alt+Return terminal · Alt+D launcher (fuzzel) ·
                       Alt+F1 cycle · Alt+Escape quit · Alt+drag move/resize
EOF
else
  warn "Build failed. If the errors are about wlr/* symbols, it's a wlroots"
  warn "version mismatch ($WLROOTS_VER vs the 0.18 pocketwl.c targets)."
  warn "Paste the first few compiler errors and I'll adapt the source."
  exit 1
fi

# ── 6. Optional: genuine GNU IceCat (heavy — kept opt-in) ─────────────────────
# Deliberately NOT part of the core install: it's a proot + Guix stack that can
# build IceCat from source for hours. Offer it, default No.
if [[ "${ICECAT:-}" == "1" ]]; then
  RUN_ICECAT=y
else
  echo ""
  echo -e "Set up genuine GNU IceCat now? (proot + Guix — heavy/slow, optional) [y/N]"
  read -t 15 -r RUN_ICECAT || true; echo
fi
case "${RUN_ICECAT,,}" in
  y|yes) bash "$DIR/icecat.sh" ;;
  *) echo ":: Skipping IceCat. Run it later with:  bash $DIR/icecat.sh" ;;
esac
