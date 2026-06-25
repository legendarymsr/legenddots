#!/usr/bin/env bash
# =============================================================================
# Resume an interrupted gentoo/install.sh run after a crash/freeze.
#
# install.sh checkpoints each major step to /etc/gentoo-install.state inside
# the new root filesystem. This script re-mounts the partitions install.sh
# already created, re-enters the chroot, and re-runs /tmp/inside.sh, which
# skips any step already marked done and continues from the one that didn't
# finish.
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

echo -e "${CYAN}Re-mounting existing install...${NC}"
mkdir -p /mnt/gentoo
mountpoint -q /mnt/gentoo       || mount /dev/sda3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mountpoint -q /mnt/gentoo/boot/efi || mount /dev/sda1 /mnt/gentoo/boot/efi
swapon /dev/sda2 2>/dev/null || true
cp -L /etc/resolv.conf /mnt/gentoo/etc/

if [[ ! -f /mnt/gentoo/tmp/inside.sh ]]; then
  echo -e "${RED}/mnt/gentoo/tmp/inside.sh is missing — there's nothing to resume.${NC}" >&2
  echo -e "${RED}Run install.sh instead (it will repartition /dev/sda from scratch).${NC}" >&2
  exit 1
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
