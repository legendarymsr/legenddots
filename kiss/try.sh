#!/usr/bin/env bash
# =============================================================================
# Try KISS Linux WITHOUT installing it. Unpacks the kiss-community rootfs into a
# directory and uses its OWN kiss-chroot to drop you in — no partitioning, no
# bootloader, no reboot, fully removable.
#
#   doas ./try.sh            # download (once) + chroot in
#   doas ./try.sh --enter    # re-enter an already-unpacked rootfs
#   doas ./try.sh --clean    # unmount + delete it
#
# Runs on any Linux (Gentoo included). The rootfs is musl, but a chroot uses its
# own libc, so it just works. Budget a few hundred MB in $DIR.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

DIR="${DIR:-/var/tmp/kiss}"
# Same release + baked checksum as install.sh — bump both together from
# https://codeberg.org/kiss-community/repo/releases (checksum is in the notes).
KISS_VER="${KISS_VER:-24.12.18}"
KISS_SHA256="${KISS_SHA256:-4e5ecef56e747029d2665a038b17a156a0cffd8ba9c99a776226aaf02bd9ff72}"
BASE_URL="https://codeberg.org/kiss-community/repo/releases/download/${KISS_VER}"
TARBALL="kiss-chroot-${KISS_VER}.tar.xz"

[[ $EUID -eq 0 ]] || die "run as root (doas ./try.sh)"
MODE="${1:-}"

unmount_all() { for m in proc sys dev; do umount -R "$DIR/$m" 2>/dev/null || true; done; }

if [[ "$MODE" == "--clean" ]]; then
  header "Removing ${DIR}"
  unmount_all
  rm -rf "$DIR"
  echo -e "${GREEN}Gone. No trace left on your system.${NC}"
  exit 0
fi

# ── Get the rootfs (unless it's already unpacked, or we're just re-entering) ──
if [[ ! -x "$DIR/bin/kiss-chroot" ]]; then
  [[ "$MODE" == "--enter" ]] && die "nothing unpacked at $DIR yet — run without --enter first"
  for t in curl tar sha256sum; do command -v "$t" >/dev/null || die "missing tool: $t"; done
  mkdir -p "$DIR"
  header "Downloading rootfs ${TARBALL}"
  ( cd "$DIR" && curl -fL# -O "${BASE_URL}/${TARBALL}" )
  if [[ -n "$KISS_SHA256" ]]; then
    header "Verifying sha256"
    ( cd "$DIR" && echo "${KISS_SHA256}  ${TARBALL}" | sha256sum -c - ) || die "checksum mismatch — aborting"
  fi
  header "Unpacking into ${DIR}"
  tar xf "$DIR/${TARBALL}" -C "$DIR"      # rootfs extracts directly; no --strip-components
  rm -f "$DIR/${TARBALL}"
fi

# ── Drop into the chroot via KISS's own helper (it mounts + unmounts for you) ─
cp -L /etc/resolv.conf "$DIR/etc/resolv.conf" 2>/dev/null || true

cat <<EOF

${GREEN}You're inside KISS.${NC} Nothing here touches your host — it all lives in ${DIR}.
Try it out:
  ${CYAN}kiss version${NC}
  ${CYAN}git clone https://codeberg.org/kiss-community/repo${NC}
  ${CYAN}export KISS_PATH=\$PWD/repo/core:\$PWD/repo/extra${NC}
  ${CYAN}kiss search zlib${NC}   ·   ${CYAN}kiss b <pkg>${NC}
Press ${YEL}Ctrl-D${NC} (or type exit) to leave.

EOF

"$DIR/bin/kiss-chroot" "$DIR" || true

unmount_all
echo -e "\n${GREEN}Left the chroot.${NC}"
echo "Re-enter:  ${CYAN}doas $0 --enter${NC}"
echo "Remove:    ${CYAN}doas $0 --clean${NC}"
