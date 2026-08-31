#!/usr/bin/env bash
# build-exvi.sh — build & install Traditional Vi (ex-vi): Gunnar Ritter's port of
# the original AT&T/BSD ex/vi, i.e. the actual Unix vi, not the nvi rewrite. It's
# self-contained — bundles its own termlib and regex — so it needs no ncurses or
# termcap, and it reads ~/.exrc natively (which vim/nvim/busybox vi do not).
#
#   bash build-exvi.sh                       # installs into ~/.local  (rootless)
#   PREFIX=/usr/local doas bash build-exvi.sh  # system-wide
#   (on Termux, $PREFIX is already the Termux prefix, so it installs there)
#
# Installs: $PREFIX/bin/{ex,vi,view} (one binary; vi = visual, view = read-only).
set -eu

VER=050325
URL="https://downloads.sourceforge.net/project/ex-vi/ex-vi/${VER}/ex-${VER}.tar.bz2"
PREFIX="${PREFIX:-$HOME/.local}"
BINDIR="$PREFIX/bin"
LIBEXECDIR="$PREFIX/libexec"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say() { echo ":: $*"; }
die() { echo "!! $*" >&2; exit 1; }

command -v make >/dev/null 2>&1 || die "need 'make' (Termux: pkg install make; Gentoo: it's in base)"
CC="$(command -v cc || command -v gcc || command -v clang || true)"
[ -n "$CC" ] || die "need a C compiler (Termux: pkg install clang; Gentoo: gcc)"

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fSL -o "$1" "$2"
  elif command -v wget >/dev/null 2>&1; then wget -O "$1" "$2"
  else die "need curl or wget to download the source"; fi
}

say "downloading ex-vi ${VER} ..."
fetch "$WORK/ex.tar.bz2" "$URL"
say "extracting ..."
tar xjf "$WORK/ex.tar.bz2" -C "$WORK"
cd "$WORK/ex-${VER}"

say "building with $CC (bundled termlib + regex, no external deps) ..."
make CC="$CC" PREFIX="$PREFIX" BINDIR="$BINDIR" LIBEXECDIR="$LIBEXECDIR" >/dev/null
[ -x ex ] || die "build produced no 'ex' binary — send me the make output"

say "installing into $BINDIR ..."
mkdir -p "$BINDIR" "$LIBEXECDIR"
install -m755 ex         "$BINDIR/ex"
install -m755 exrecover  "$LIBEXECDIR/exrecover"  2>/dev/null || true
install -m755 expreserve "$LIBEXECDIR/expreserve" 2>/dev/null || true
ln -sfn ex "$BINDIR/vi"     # invoked as vi -> visual mode
ln -sfn ex "$BINDIR/view"   # invoked as view -> read-only

say "done — 'vi' and 'ex' are in $BINDIR"
case ":$PATH:" in *":$BINDIR:"*) ;; *) say "add it to PATH:  export PATH=\"$BINDIR:\$PATH\"" ;; esac
say "it reads ~/.exrc — link the repo config:  ln -sfn \"\$PWD/exrc\" ~/.exrc"
