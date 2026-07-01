#!/usr/bin/env bash
# =============================================================================
# Chroot back into an in-progress gentoo/install.sh run -- after a crash,
# a freeze, or just a deliberate reboot. The script doesn't know or care
# which one happened; either way the disk is in the same state and this
# script's only job is to get you back into a working chroot on it.
#
# What it does, in order:
#   1. Re-mounts the partitions install.sh already created (/dev/sda1
#      EFI, /dev/sda2 swap, /dev/sda3 root) plus proc/sys/dev/run --
#      it never repartitions or re-unpacks stage3, only resumes.
#   2. Re-extracts the chroot logic fresh from the adjacent install.sh
#      into /mnt/gentoo/tmp/inside.sh, so a `git pull`-ed fix since the
#      original run gets picked up instead of re-running the stale copy
#      baked in from before.
#   3. Detects a couple of known-stale states (invalid package.mask left
#      by an old bug, a too-new/incompatible kernel already built) and
#      auto-corrects them by forcing the affected steps to rerun.
#   4. chroots in and re-runs inside.sh. install.sh checkpoints each
#      major step to /etc/gentoo-install.state inside the new root as it
#      completes them, so steps already marked done are skipped --
#      picking up exactly where the previous run stopped. Any package
#      that finished building before now gets reused from the local
#      binpkg cache (FEATURES="buildpkg", PKGDIR=/var/cache/binpkgs)
#      instead of recompiled, even if its step gets forced to rerun.
#
# There's nothing to "resume" if /dev/sda3 doesn't even exist yet -- stage3
# was never unpacked, so there's no chroot to get back into. In that case
# this script just hands off to the adjacent install.sh instead, which
# does the actual from-scratch partitioning/unpacking.
#
# Boot the same live ISO, tether internet again, then:
#   bash resume.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

[[ $EUID -eq 0 ]] || exit 1

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
INSTALL_SH="${SCRIPT_DIR}/install.sh"

if [[ ! -e /dev/sda3 ]]; then
  if [[ -f "$INSTALL_SH" ]]; then
    echo -e "${CYAN}No existing install found on /dev/sda3 — stage3 was never unpacked, nothing to resume. Running install.sh instead...${NC}"
    exec bash "$INSTALL_SH"
  fi
  echo -e "${RED}No existing install found on /dev/sda3, and install.sh isn't next to resume.sh — can't proceed.${NC}" >&2
  exit 1
fi

echo -e "${CYAN}Re-mounting existing install...${NC}"
mkdir -p /mnt/gentoo
mountpoint -q /mnt/gentoo       || mount /dev/sda3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mountpoint -q /mnt/gentoo/boot/efi || mount /dev/sda1 /mnt/gentoo/boot/efi
swapon /dev/sda2 2>/dev/null || true
cp -L /etc/resolv.conf /mnt/gentoo/etc/

if [[ -f "$INSTALL_SH" ]]; then
  echo -e "${CYAN}Regenerating /tmp/inside.sh from $(basename "$INSTALL_SH")...${NC}"
  awk '/^cat << .CHROOT_EOF.* > \/mnt\/gentoo\/tmp\/inside\.sh$/{flag=1; next} /^CHROOT_EOF$/{flag=0} flag' \
    "$INSTALL_SH" > /mnt/gentoo/tmp/inside.sh
  chmod +x /mnt/gentoo/tmp/inside.sh
elif [[ ! -f /mnt/gentoo/tmp/inside.sh ]]; then
  echo -e "${RED}install.sh not found next to resume.sh, and /mnt/gentoo/tmp/inside.sh is missing.${NC}" >&2
  echo -e "${RED}Run install.sh instead (it will repartition /dev/sda from scratch).${NC}" >&2
  exit 1
else
  echo -e "${CYAN}install.sh not found next to resume.sh — reusing the existing /tmp/inside.sh as-is.${NC}"
fi

mountpoint -q /mnt/gentoo/proc || mount --types proc proc /mnt/gentoo/proc
mountpoint -q /mnt/gentoo/sys  || { mount --rbind /sys /mnt/gentoo/sys; mount --make-rslave /mnt/gentoo/sys; }
mountpoint -q /mnt/gentoo/dev  || { mount --rbind /dev /mnt/gentoo/dev; mount --make-rslave /mnt/gentoo/dev; }
mountpoint -q /mnt/gentoo/run  || mount --bind /run /mnt/gentoo/run

# An earlier version of this fix wrote an invalid package.mask atom
# (`~sys-kernel/gentoo-sources` -- the `~` version operator requires an
# actual version, it doesn't mean "all testing-keyword ebuilds"). Portage
# silently ignored it and kept building the testing kernel. Clean up that
# stray file if a prior resume left it behind.
rm -f /mnt/gentoo/etc/portage/package.mask/gentoo-sources-stable

# A kernel built before the broadcom-sta fixes will fail the base_system
# emerge the same way every time it's resumed, even with a freshly
# regenerated inside.sh, since "kernel" is already marked done. Detect
# either stale failure mode and force kernel + base_system to rerun.
if [[ -f /mnt/gentoo/etc/gentoo-install.state ]] && grep -qx kernel /mnt/gentoo/etc/gentoo-install.state; then
  KVER=""
  [[ -e /mnt/gentoo/usr/src/linux ]] && \
    KVER=$(basename "$(readlink -f /mnt/gentoo/usr/src/linux)" | sed -E 's/^linux-//; s/-gentoo$//')
  KMAJOR="${KVER%%.*}"

  if [[ "$KMAJOR" =~ ^[0-9]+$ ]] && (( KMAJOR >= 7 )); then
    # Too new: broadcom-sta's out-of-tree source isn't patched for testing-
    # branch kernels this far ahead. Unmerge it and force a rebuild, which
    # will now pull the stable kernel via ACCEPT_KEYWORDS=amd64 in install.sh.
    echo -e "${CYAN}Kernel ${KVER} is from the testing branch and too new for broadcom-sta — unmerging it and forcing a rebuild on the latest stable kernel...${NC}"
    chroot /mnt/gentoo emerge --unmerge "=sys-kernel/gentoo-sources-${KVER}*" 2>/dev/null || true
    rm -rf "/mnt/gentoo/usr/src/linux-${KVER}-gentoo"
    rm -f /mnt/gentoo/usr/src/linux
    sed -i '/^kernel$/d; /^base_system$/d' /mnt/gentoo/etc/gentoo-install.state
  elif [[ -f /mnt/gentoo/usr/src/linux/.config ]] \
    && grep -qE '^CONFIG_(PREEMPT_RCU|BRCMFMAC|BRCMSMAC|BRCMUTIL|B43|B43LEGACY|SSB|MAC80211)=y' /mnt/gentoo/usr/src/linux/.config; then
    echo -e "${CYAN}Stale kernel config detected (broadcom-sta incompatible) — forcing kernel + base_system rebuild...${NC}"
    sed -i '/^kernel$/d; /^base_system$/d' /mnt/gentoo/etc/gentoo-install.state
  fi
fi

# An earlier version of WD-40 only unmasked x11-terms/alacritty, but
# gnome-base/librsvg hits the same wall (every Rust-based version is masked,
# and the one pre-Rust version was never keyworded for amd64) -- it's pulled
# in transitively by media-sound/pavucontrol's GTK4 dependency. If wd40 is
# already marked done from a run before that fix existed, the unmask file
# either doesn't exist yet or is missing the librsvg line; force a rerun so
# the new unmask actually lands before the desktop step retries.
#
# A later fix found that librsvg's own IUSE defaults "+introspection +vala"
# on, and REQUIRED_USE="vala? ( introspection )" -- since this profile's
# global USE already turns introspection off, leaving vala on by itself
# fails that constraint. If wd40 ran after the unmask fix but before this
# USE fix, package.use/librsvg won't exist yet either; force another rerun.
if [[ -f /mnt/gentoo/etc/gentoo-install.state ]] && grep -qx wd40 /mnt/gentoo/etc/gentoo-install.state; then
  if ! grep -qx gnome-base/librsvg /mnt/gentoo/etc/portage/package.unmask/wd40-exceptions 2>/dev/null \
    || ! grep -q '^gnome-base/librsvg .*-vala' /mnt/gentoo/etc/portage/package.use/librsvg 2>/dev/null; then
    echo -e "${CYAN}Stale wd40 state detected (missing librsvg unmask/USE fix) — forcing wd40 to rerun...${NC}"
    sed -i '/^wd40$/d' /mnt/gentoo/etc/gentoo-install.state
  fi
fi

# Finalize ran without generating refind_linux.conf, so rEFInd booted the
# kernel bare (no initramfs) → kernel panic at root mount. Force finalize to
# rerun if the file is missing so it gets created with the correct UUID and
# initramfs path.
if [[ -f /mnt/gentoo/etc/gentoo-install.state ]] && grep -qx finalize /mnt/gentoo/etc/gentoo-install.state; then
  if [[ ! -f /mnt/gentoo/boot/refind_linux.conf ]] \
    || ! grep -q 'acpi_osi=' /mnt/gentoo/boot/refind_linux.conf \
    || ! grep -q 'i915.enable_psr=0' /mnt/gentoo/boot/refind_linux.conf \
    || ! grep -q 'pcie_aspm=off' /mnt/gentoo/boot/refind_linux.conf \
    || ! grep -q 'nomodeset' /mnt/gentoo/boot/refind_linux.conf; then
    echo -e "${CYAN}Stale finalize state detected (refind_linux.conf missing or lacks required boot params) — forcing finalize to rerun...${NC}"
    sed -i '/^finalize$/d' /mnt/gentoo/etc/gentoo-install.state
  fi
fi

if [[ -f /mnt/gentoo/etc/gentoo-install.state ]]; then
  echo -e "${CYAN}Steps already completed:${NC}"
  cat /mnt/gentoo/etc/gentoo-install.state
  echo
else
  echo -e "${CYAN}No completed steps recorded yet — resuming from the start.${NC}"
fi

header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
header "Chrooting back in to resume install..."
chroot /mnt/gentoo /tmp/inside.sh
sync
echo -e "${GREEN}Reboot now: umount -R /mnt/gentoo && reboot${NC}"
