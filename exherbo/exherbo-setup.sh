#!/usr/bin/env bash
# =============================================================================
# Exherbo in-chroot setup — runs INSIDE the chroot from install.sh.
# Syncs the cave/paludis repos, configures the system, then builds a kernel +
# bootloader so the box actually boots. Source-based, so budget time.
# =============================================================================
set -eu

CYAN='\033[0;36m'; YEL='\033[0;33m'; GRN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
header() { printf '\n%b── %s %b\n' "$CYAN" "$*" "$NC"; }
warn()   { printf '%b! %s%b\n' "$YEL" "$*" "$NC"; }

HOSTNAME_="${HOSTNAME_:-exherbo}"
TIMEZONE="${TIMEZONE:-America/New_York}"
LOCALE="${LOCALE:-en_US.UTF-8}"
PRIV_ESC="${PRIV_ESC:-doas}"

# Exherbo's environment (PATHs, paludis vars) comes from /etc/profile.
# shellcheck disable=SC1091
source /etc/profile 2>/dev/null || true

# cave resolve with execution + as few prompts as possible.
RESOLVE="cave resolve -x --continue-on-failure if-independent"

# ── System identity ───────────────────────────────────────────────────────────
header "System configuration"
printf '%s\n' "$HOSTNAME_" > /etc/hostname
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
printf '%s\n' "$TIMEZONE" > /etc/timezone 2>/dev/null || true
cat > /etc/hosts <<EOF
127.0.0.1  localhost $HOSTNAME_
::1        localhost $HOSTNAME_
EOF
# Locale: prefer eclectic (the Exherbo way); fall back to /etc/locale.conf.
if command -v eclectic >/dev/null 2>&1; then
  eclectic locale set "$LOCALE" 2>/dev/null || warn "set the locale later: eclectic locale list/set"
fi
printf 'LANG=%s\n' "$LOCALE" > /etc/locale.conf 2>/dev/null || true

# ── Sync the repositories ─────────────────────────────────────────────────────
# The stage ships a working /etc/paludis config with the core 'arbor' repo (and
# usually 'x11', 'kde', etc. available). cave sync pulls the latest git trees.
header "Syncing cave/paludis repositories (cave sync)"
cave sync || warn "cave sync failed — check networking + /etc/paludis, then re-run"

# Keep paludis itself current before a big resolve.
header "Updating the package mover"
$RESOLVE sys-apps/paludis 2>/dev/null || warn "paludis self-update skipped"

# ── Networking (systemd — Exherbo's default init) ─────────────────────────────
# Exherbo is systemd-first, so wire DHCP via systemd-networkd + resolved.
header "Networking (systemd-networkd DHCP)"
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/10-dhcp.network <<'EOF'
[Match]
Name=en* eth* wl*
[Network]
DHCP=yes
EOF
systemctl enable systemd-networkd systemd-resolved 2>/dev/null || warn "enable networkd/resolved after boot"
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
# NOTE — MacBook Air wifi: the BCM4360 needs the proprietary broadcom 'wl' driver
# (net-wireless/broadcom-sta), an out-of-tree module. Ethernet / USB-tether work
# out of the box; build broadcom-sta after the kernel and load 'wl' for wifi.

# ── Firmware + kernel (Exherbo does NOT package the kernel) ────────────────────
# There's no sys-kernel/linux in Exherbo — you build the kernel from kernel.org,
# like LFS/KISS. Only the firmware blobs come from cave (unqualified: linux-firmware).
header "Installing firmware + building the kernel from kernel.org — the long part"
$RESOLVE linux-firmware || warn "linux-firmware resolve failed (try: cave resolve -x linux-firmware)"
# tools the kernel build wants; the gcc stage usually already has them
$RESOLVE bc flex bison 2>/dev/null || true

KVER="${KVER:-$(curl -fsSL https://www.kernel.org/finger_banner 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)}"
KVER="${KVER:-6.12.9}"
cd /usr/src
if [ ! -d "linux-${KVER}" ]; then
  header "Fetching linux-${KVER}"
  curl -fL# -O "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz" \
    && tar xf "linux-${KVER}.tar.xz" && rm -f "linux-${KVER}.tar.xz" \
    || warn "kernel download/extract failed — build one by hand from kernel.org"
fi
KSRC="/usr/src/linux-${KVER}"
if [ -d "$KSRC" ]; then
  cd "$KSRC"
  make defconfig
  # Build the disk/root/fs drivers straight IN so the box boots with NO initramfs,
  # both in the KVM guest (virtio) and on the MacBook (AHCI/NVMe + the vfat ESP).
  ./scripts/config \
    -e VIRTIO -e VIRTIO_PCI -e VIRTIO_BLK -e VIRTIO_NET -e VIRTIO_CONSOLE \
    -e SATA_AHCI -e ATA -e ATA_PIIX -e BLK_DEV_NVME \
    -e EXT4_FS -e VFAT_FS -e FAT_FS \
    -e NLS_CODEPAGE_437 -e NLS_ISO8859_1 -e USB_STORAGE
  make olddefconfig
  make -j"$(nproc)"
  make modules_install
  # Put the kernel on the ESP (/boot) ourselves — don't rely on installkernel.
  cp -f arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"
  cp -f System.map "/boot/System.map-${KVER}" 2>/dev/null || true
  cd /
else
  warn "no kernel sources under /usr/src — build a kernel by hand (kernel.org)"
  KVER=""
fi

# ── Bootloader: systemd-boot (Exherbo is systemd-first — no grub needed) ───────
# systemd-boot ships with systemd (bootctl): no build options, no efibootmgr, and
# with the drivers built in above, no initramfs. Much simpler than grub here.
header "Installing the bootloader (systemd-boot)"
if bootctl install 2>/dev/null; then
  ROOT_UUID="$(findmnt -no UUID / 2>/dev/null || true)"
  [ -z "$ROOT_UUID" ] && ROOT_UUID="$(blkid -s UUID -o value "$(findmnt -no SOURCE / 2>/dev/null)" 2>/dev/null || true)"
  mkdir -p /boot/loader/entries
  cat > /boot/loader/loader.conf <<EOF
default exherbo
timeout 3
editor  yes
EOF
  if [ -n "${KVER}" ] && [ -n "${ROOT_UUID}" ]; then
    cat > /boot/loader/entries/exherbo.conf <<EOF
title   Exherbo
linux   /vmlinuz-${KVER}
options root=UUID=${ROOT_UUID} rw
EOF
  else
    warn "couldn't write the boot entry (KVER='${KVER}' ROOT_UUID='${ROOT_UUID}') — add /boot/loader/entries/exherbo.conf by hand"
  fi
else
  warn "bootctl install failed — is /boot the mounted ESP? install a bootloader by hand"
fi

# ── Privilege escalation ──────────────────────────────────────────────────────
header "Privilege escalation (${PRIV_ESC})"
if [ "$PRIV_ESC" = "doas" ]; then
  # doas isn't in arbor — it lives in the third-party 'somasis' repo. Enable it,
  # sync, then install (the same 'unavailable repo' dance as tombriden/fastfetch).
  $RESOLVE repository/somasis 2>/dev/null || warn "couldn't add the somasis repo (doas lives there)"
  cave sync somasis 2>/dev/null || cave sync 2>/dev/null || true
  if $RESOLVE app-admin/doas; then
    echo "permit persist :wheel" > /etc/doas.conf && chmod 0400 /etc/doas.conf
  else
    warn "doas install failed (somasis repo) — falling back to sudo"
    $RESOLVE sudo && { mkdir -p /etc/sudoers.d; echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel; }
  fi
else
  $RESOLVE sudo || warn "install sudo by hand"
  mkdir -p /etc/sudoers.d
  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
fi

# ── Users & passwords ─────────────────────────────────────────────────────────
header "Set the root password"
passwd root
printf '%bCreate a regular user? enter a name (blank to skip):%b ' "$YEL" "$NC"
read -r USERNAME || USERNAME=""
if [ -n "$USERNAME" ]; then
  groupadd -f wheel 2>/dev/null || true
  useradd -mG wheel -s /bin/bash "$USERNAME" || true
  printf 'set %s password:\n' "$USERNAME"; passwd "$USERNAME" || true
fi

header "chroot setup complete"
printf '%bExit the chroot, then: swapoff, umount -R the target, reboot.%b\n' "$GRN" "$NC"
printf 'After boot: add a desktop with cave (e.g. `cave resolve -x x11-wm/…`) and build broadcom-sta for wifi.\n'
