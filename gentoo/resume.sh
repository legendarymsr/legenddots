#!/usr/bin/env bash
# =============================================================================
# Resume an interrupted gentoo/install.sh run after a crash/freeze.
#
# install.sh checkpoints each major step to /etc/gentoo-install.state inside
# the new root filesystem. This script re-mounts the partitions install.sh
# already created, re-extracts the chroot logic fresh from the adjacent
# install.sh (so fixes made to install.sh since the original run are picked
# up rather than re-running the stale copy baked into /tmp/inside.sh), then
# re-enters the chroot. Steps already marked done are skipped, continuing
# from the one that didn't finish.
#
# Boot the same live ISO, tether internet again, then:
#   bash resume.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

[[ $EUID -eq 0 ]] || exit 1

if [[ ! -e /dev/sda3 ]]; then
  echo -e "${RED}No existing install found on /dev/sda3 — run install.sh instead.${NC}" >&2
  exit 1
fi

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
INSTALL_SH="${SCRIPT_DIR}/install.sh"

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

# A kernel built before the broadcom-sta PREEMPT_RCU/in-tree-driver fix will
# fail the base_system emerge the same way every time it's resumed, even
# with a freshly regenerated inside.sh, since "kernel" is already marked
# done. Detect that stale config and force both steps to rerun.
if [[ -f /mnt/gentoo/etc/gentoo-install.state ]] \
  && grep -qx kernel /mnt/gentoo/etc/gentoo-install.state \
  && [[ -f /mnt/gentoo/usr/src/linux/.config ]] \
  && grep -qE '^CONFIG_(PREEMPT_RCU|BRCMFMAC|BRCMSMAC|BRCMUTIL|B43|B43LEGACY|SSB|MAC80211)=y' /mnt/gentoo/usr/src/linux/.config; then
  echo -e "${CYAN}Stale kernel config detected (broadcom-sta incompatible) — forcing kernel + base_system rebuild...${NC}"
  sed -i '/^kernel$/d; /^base_system$/d' /mnt/gentoo/etc/gentoo-install.state
fi

if [[ -f /mnt/gentoo/etc/gentoo-install.state ]]; then
  echo -e "${CYAN}Steps already completed:${NC}"
  cat /mnt/gentoo/etc/gentoo-install.state
  echo
else
  echo -e "${CYAN}No completed steps recorded yet — resuming from the start.${NC}"
fi

mountpoint -q /mnt/gentoo/proc || mount --types proc proc /mnt/gentoo/proc
mountpoint -q /mnt/gentoo/sys  || { mount --rbind /sys /mnt/gentoo/sys; mount --make-rslave /mnt/gentoo/sys; }
mountpoint -q /mnt/gentoo/dev  || { mount --rbind /dev /mnt/gentoo/dev; mount --make-rslave /mnt/gentoo/dev; }
mountpoint -q /mnt/gentoo/run  || mount --bind /run /mnt/gentoo/run

header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
header "Resuming install..."
chroot /mnt/gentoo /tmp/inside.sh
sync
echo -e "${GREEN}Reboot now: umount -R /mnt/gentoo && reboot${NC}"
