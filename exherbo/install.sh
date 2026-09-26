#!/usr/bin/env bash
# =============================================================================
# Exherbo Linux Install Script — cave / paludis, exheres-0, UEFI x86_64
# Mirrors the flow of gentoo/install.sh and kiss/install.sh: partition ->
# unpack a stage -> fstab -> chroot -> sync/build. Source-based, so it compiles
# a kernel and toolchain bits — budget time. Run from any Linux live env as root.
#
# One command, and it does the rest:
#   ./install.sh            auto — fresh install on an empty disk, RESUME an
#                           existing one (no wipe). Re-run any time to continue.
#   ./install.sh fresh      force a clean wipe + install
#   ./install.sh resume     re-enter an existing install and finish the build
#
# It self-updates (git pull) and, on resume, re-mounts everything for you — so
# if a build step ever fails, you just run it again.
#
# Exherbo is systemd-first: this is the ONE systemd system in legenddots. If you
# want no-systemd, that's what gentoo/ (OpenRC), kiss/ and blfs/ are for.
#
# Reference: https://exherbo.org/docs/install-guide.html
# =============================================================================
set -euo pipefail

# Capture this script's own directory NOW, before any `cd` (we cd into $MNT
# later, which would otherwise break a relative "$0").
SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# ── Colours & helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }
is_mounted() { mountpoint -q "$1" 2>/dev/null || grep -q " $1 " /proc/mounts 2>/dev/null; }

# ── Self-update: pull the latest fixes, then re-exec the fresh copy once ───────
# So you always run the newest installer without a manual `git pull`.
if [[ -z "${INSTALL_SELFUPDATED:-}" ]] && command -v git >/dev/null 2>&1 \
   && git -C "$SELF_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  header "Updating installer to latest (git pull)"
  if git -C "$SELF_DIR" pull --ff-only >/dev/null 2>&1; then
    export INSTALL_SELFUPDATED=1
    exec "$SELF_DIR/$(basename "$0")" "$@"
  else
    warn "git pull skipped (offline or local changes) — using this checkout"
  fi
fi

# ── Configuration (10s prompts, sane defaults if untouched) ───────────────────
STAGE_BASE="${STAGE_BASE:-https://stages.exherbo.org/x86_64-pc-linux-gnu}"
STAGE_FILE="${STAGE_FILE:-exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz}"
VERIFY="${VERIFY:-true}"

if [[ -z "${DISK:-}" ]]; then
  echo -e "${CYAN}Target disk? (10s, default: /dev/sda)${NC}"
  read -t 10 -r ANS || true; echo
  DISK="${ANS:-/dev/sda}"
fi
if [[ -z "${PRIV_ESC:-}" ]]; then
  echo -e "${CYAN}Privilege-escalation tool for the installed system? [doas/sudo] (10s, default: doas)${NC}"
  read -t 10 -r ANS || true; echo
  case "${ANS,,}" in sudo) PRIV_ESC="sudo" ;; *) PRIV_ESC="doas" ;; esac
fi
HOSTNAME_="${HOSTNAME_:-exherbo}"
TIMEZONE="${TIMEZONE:-America/New_York}"
LOCALE="${LOCALE:-en_US.UTF-8}"

MNT=/mnt/exherbo

# ── Pre-flight ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "run as root"
[[ -b "$DISK" ]]  || die "$DISK is not a block device"
[[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode (this installer is UEFI-only)"
for t in sgdisk mkfs.fat mkfs.ext4 curl tar sha256sum blkid partprobe; do
  command -v "$t" >/dev/null || die "missing tool: $t"
done

# Partition node names differ for nvme/mmc (p1) vs sata/usb (1).
case "$DISK" in *[0-9]) P="${DISK}p" ;; *) P="${DISK}" ;; esac
EFI="${P}1"; SWAP="${P}2"; ROOT="${P}3"

# ── Is there already an Exherbo base on this disk? Then resume, don't wipe. ────
is_existing() {
  mkdir -p "$MNT"
  if is_mounted "$MNT"; then
    [[ -d "$MNT/etc/paludis" || -d "$MNT/var/db/paludis" ]]; return
  fi
  if mount "$ROOT" "$MNT" 2>/dev/null; then
    if [[ -d "$MNT/etc/paludis" || -d "$MNT/var/db/paludis" ]]; then return 0; fi
    umount "$MNT" 2>/dev/null || true
  fi
  return 1
}

# ── Mode selection ────────────────────────────────────────────────────────────
ARG="${1:-}"
case "$ARG" in
  fresh)  MODE=fresh ;;
  resume) MODE=resume ;;
  "")     if is_existing; then MODE=resume; else MODE=fresh; fi ;;
  *)      die "unknown mode '$ARG' (use: fresh | resume)" ;;
esac

# ── Fresh install: wipe, partition, unpack the stage ──────────────────────────
do_fresh() {
  echo -e "${YEL}About to ERASE ${DISK} and install Exherbo. Ctrl-C now to abort.${NC}"
  sleep 5

  header "Partitioning ${DISK} (512M EFI + 4G swap + rest root)"
  swapoff -a || true
  umount -R "$MNT" 2>/dev/null || true
  sgdisk --zap-all "$DISK"
  sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:EFI  "$DISK"
  sgdisk --new=2:0:+4G   --typecode=2:8200 --change-name=2:swap "$DISK"
  sgdisk --new=3:0:0     --typecode=3:8304 --change-name=3:root "$DISK"
  partprobe "$DISK"; udevadm settle 2>/dev/null || sleep 2

  header "Filesystems"
  mkfs.fat -F32 "$EFI"
  mkswap "$SWAP"; swapon "$SWAP"
  mkfs.ext4 -F "$ROOT"

  header "Mounting at ${MNT}"
  mkdir -p "$MNT"
  mount "$ROOT" "$MNT"
  mkdir -p "$MNT/boot"
  mount "$EFI" "$MNT/boot"

  header "Downloading stage ${STAGE_FILE}"
  ( cd "$MNT" && curl -fL# -O "${STAGE_BASE}/${STAGE_FILE}" )
  if [[ "$VERIFY" == "true" ]]; then
    header "Verifying sha256"
    if ( cd "$MNT" && curl -fLs -O "${STAGE_BASE}/${STAGE_FILE}.sha256sum" ); then
      WANT="$(awk '{print $1}' "${MNT}/${STAGE_FILE}.sha256sum" | head -1)"
      ( cd "$MNT" && echo "${WANT}  ${STAGE_FILE}" | sha256sum -c - ) || die "checksum mismatch — aborting"
      rm -f "${MNT}/${STAGE_FILE}.sha256sum"
    else
      warn "no .sha256 published for this stage — skipping verification"
    fi
  fi
  header "Unpacking the stage into ${MNT}"
  tar xJpf "${MNT}/${STAGE_FILE}" -C "$MNT" --xattrs-include='*.*' --numeric-owner
  rm -f "${MNT}/${STAGE_FILE}"

  header "Generating /etc/fstab"
  {
    echo "# <device>                                   <mount> <type> <opts>           <dump> <pass>"
    printf 'UUID=%-36s /       ext4   defaults         0 1\n'  "$(blkid -s UUID -o value "$ROOT")"
    printf 'UUID=%-36s /boot   vfat   defaults,noatime 0 2\n'  "$(blkid -s UUID -o value "$EFI")"
    printf 'UUID=%-36s none    swap   sw               0 0\n'  "$(blkid -s UUID -o value "$SWAP")"
  } > "$MNT/etc/fstab"
}

# ── Resume: an install already exists — just mount it and finish the build ────
do_resume() {
  header "Existing Exherbo on ${ROOT} — RESUME (no wipe)"
  swapon "$SWAP" 2>/dev/null || true
  mkdir -p "$MNT"
  is_mounted "$MNT"      || mount "$ROOT" "$MNT"
  mkdir -p "$MNT/boot"
  is_mounted "$MNT/boot" || mount "$EFI" "$MNT/boot" 2>/dev/null || \
    warn "couldn't mount the ESP at $MNT/boot — the bootloader step may fail"
}

# ── Bind pseudo-filesystems + DNS (idempotent), then enter the chroot ─────────
bind_pseudo() {
  header "Binding pseudo-filesystems + DNS"
  cp -L /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true
  is_mounted "$MNT/dev"  || { mount --rbind /dev  "$MNT/dev"  && mount --make-rslave "$MNT/dev"; }
  is_mounted "$MNT/sys"  || { mount --rbind /sys  "$MNT/sys"  && mount --make-rslave "$MNT/sys"; }
  is_mounted "$MNT/proc" || mount -t proc none "$MNT/proc"
  is_mounted "$MNT/run"  || { mount --rbind /run  "$MNT/run"  && mount --make-rslave "$MNT/run" || true; }
}

enter_chroot() {
  header "Entering chroot to sync & build"
  install -Dm755 "$SELF_DIR/exherbo-setup.sh" "$MNT/exherbo-setup.sh"
  if env -i HOME=/root TERM="${TERM:-linux}" \
       HOSTNAME_="$HOSTNAME_" TIMEZONE="$TIMEZONE" LOCALE="$LOCALE" PRIV_ESC="$PRIV_ESC" \
       "$(command -v chroot)" "$MNT" /bin/bash -lc '/exherbo-setup.sh'; then
    header "Done"
    echo -e "${GREEN}Exherbo installed. Unmount and reboot:${NC}"
    echo "  swapoff -a; umount -R ${MNT}; reboot"
  else
    warn "setup didn't finish cleanly — nothing is lost. Just run it again to resume:"
    echo -e "  ${GREEN}DISK=${DISK} $0${NC}   ${CYAN}(auto-detects the existing install and continues)${NC}"
    exit 1
  fi
}

# ── Go ────────────────────────────────────────────────────────────────────────
if [[ "$MODE" == fresh ]]; then do_fresh; else do_resume; fi
bind_pseudo
enter_chroot
