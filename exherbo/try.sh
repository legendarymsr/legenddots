#!/usr/bin/env bash
# =============================================================================
# Try Exherbo WITHOUT installing it. Unpacks a stage into a directory on your
# existing Linux box (Gentoo, whatever) and chroots in so you can play with
# cave/paludis — no partitioning, no bootloader, no reboot, fully removable.
#
#   doas ./try.sh            # download (once) + chroot in
#   doas ./try.sh --enter    # re-enter an already-unpacked stage
#   doas ./try.sh --clean    # unmount + delete it
#
# Since you already run a source distro, exheres will feel like ebuilds and cave
# like portage. Budget a few hundred MB in $DIR (more once you build anything).
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

DIR="${DIR:-/var/tmp/exherbo}"
STAGE_BASE="${STAGE_BASE:-https://dev.exherbo.org/stages}"
STAGE_FILE="${STAGE_FILE:-exherbo-x86_64-current.tar.xz}"
VERIFY="${VERIFY:-true}"

[[ $EUID -eq 0 ]] || die "run as root (doas ./try.sh)"
MODE="${1:-}"

unmount_all() { umount -R "$DIR" 2>/dev/null || true; }

if [[ "$MODE" == "--clean" ]]; then
  header "Removing ${DIR}"
  unmount_all
  rm -rf "$DIR"
  echo -e "${GREEN}Gone. No trace left on your system.${NC}"
  exit 0
fi

# ── Get the stage (unless it's already unpacked, or we're just re-entering) ───
if [[ ! -x "$DIR/bin/bash" ]]; then
  [[ "$MODE" == "--enter" ]] && die "nothing unpacked at $DIR yet — run without --enter first"
  for t in curl tar sha256sum; do command -v "$t" >/dev/null || die "missing tool: $t"; done
  mkdir -p "$DIR"
  header "Downloading stage ${STAGE_FILE}"
  ( cd "$DIR" && curl -fL# -O "${STAGE_BASE}/${STAGE_FILE}" )
  if [[ "$VERIFY" == "true" ]] && ( cd "$DIR" && curl -fLs -O "${STAGE_BASE}/${STAGE_FILE}.sha256" ); then
    header "Verifying sha256"
    ( cd "$DIR" && echo "$(awk '{print $1}' "${STAGE_FILE}.sha256" | head -1)  ${STAGE_FILE}" | sha256sum -c - ) \
      || die "checksum mismatch — aborting"
    rm -f "$DIR/${STAGE_FILE}.sha256"
  fi
  header "Unpacking into ${DIR}"
  tar xJpf "$DIR/${STAGE_FILE}" -C "$DIR" --xattrs-include='*.*' --numeric-owner
  rm -f "$DIR/${STAGE_FILE}"
fi

# ── Bind the pseudo-filesystems + DNS, then drop into the chroot ──────────────
header "Binding pseudo-filesystems"
cp -L /etc/resolv.conf "$DIR/etc/resolv.conf" 2>/dev/null || true
mount --rbind /dev "$DIR/dev" && mount --make-rslave "$DIR/dev"
mount --rbind /sys "$DIR/sys" && mount --make-rslave "$DIR/sys"
mount -t proc none "$DIR/proc"
mount --rbind /run "$DIR/run" && mount --make-rslave "$DIR/run" || true
trap unmount_all EXIT

cat <<EOF

${GREEN}You're inside Exherbo.${NC} Nothing here touches your host — it all lives in ${DIR}.
Try it out:
  ${CYAN}cave sync${NC}                 # sync the repos (needs network)
  ${CYAN}cave show arbor${NC}           # look at the core repo
  ${CYAN}cave resolve -x nano${NC}      # resolve + build a package
Press ${YEL}Ctrl-D${NC} (or type exit) to leave.

EOF

env -i HOME=/root TERM="${TERM:-linux}" PS1='(exherbo) \w \$ ' \
    "$(command -v chroot)" "$DIR" /bin/bash -l || true

unmount_all
trap - EXIT
echo -e "\n${GREEN}Left the chroot.${NC}"
echo "Re-enter:  ${CYAN}doas $0 --enter${NC}"
echo "Remove:    ${CYAN}doas $0 --clean${NC}"
