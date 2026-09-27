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

# Download helpers — the Exherbo stage ships wget (paludis uses it), NOT always
# curl, so never hard-depend on curl in here.
fetch()   { if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"; else wget -qO- "$1"; fi; }
dl_file() { if command -v curl >/dev/null 2>&1; then curl -fL# -o "$2" "$1"; else wget -O "$2" "$1"; fi; }

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
# DNS for the REST of this chroot: systemd-resolved isn't running in here, so we
# must NOT point resolv.conf at its /run stub now — doing that is what killed
# every fetch after this step (linux-firmware, the kernel, doas: "Temporary
# failure in name resolution"). Keep a real, working resolver instead; a prior
# run may also have left a dead stub symlink, so heal it if lookups are broken.
if ! getent hosts cdn.kernel.org >/dev/null 2>&1; then
  rm -f /etc/resolv.conf
  printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
fi
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

# Latest stable from kernel.org's finger_banner (the "latest stable" line), with
# a known-good fallback. The vN.x download path is derived from the major, so
# this tracks whatever's current (7.x now) instead of a hardcoded series.
# Override with KVER=x.y.z for a specific version.
KVER="${KVER:-$(fetch https://www.kernel.org/finger_banner 2>/dev/null | awk '/latest stable version/{print $NF; exit}')}"
KVER="${KVER:-7.2.8}"
KMAJ="${KVER%%.*}"
cd /usr/src
if [ ! -d "linux-${KVER}" ]; then
  header "Fetching linux-${KVER}"
  if dl_file "https://cdn.kernel.org/pub/linux/kernel/v${KMAJ}.x/linux-${KVER}.tar.xz" "linux-${KVER}.tar.xz"; then
    tar xf "linux-${KVER}.tar.xz" && rm -f "linux-${KVER}.tar.xz"
  else
    warn "kernel download failed (no curl/wget, or network) — build one by hand"
  fi
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

# ── Bootloader: systemd-boot, with a direct-EFISTUB fallback ──────────────────
# Prefer systemd-boot (bootctl) — but Exherbo's systemd may not ship the sd-boot
# EFI binary, in which case we boot the kernel *itself* as an EFI app (CONFIG_
# EFI_STUB) with root= baked in. Either way the loader lands at the removable
# path \EFI\BOOT\BOOTX64.EFI, which is what OVMF *and* a real Mac's firmware boot
# with no NVRAM entry needed.
header "Installing the bootloader"
ROOT_UUID="$(findmnt -no UUID / 2>/dev/null || true)"
[ -z "$ROOT_UUID" ] && ROOT_UUID="$(blkid -s UUID -o value "$(findmnt -no SOURCE / 2>/dev/null)" 2>/dev/null || true)"
mkdir -p /boot/EFI/BOOT /boot/EFI/systemd /boot/loader/entries

SDBOOT="$(find /usr -name 'systemd-bootx64.efi' 2>/dev/null | head -1)"
if [ -n "$SDBOOT" ]; then
  printf 'systemd-boot binary: %s\n' "$SDBOOT"
  bootctl --esp-path=/boot install || warn "bootctl returned an error — falling back to a manual copy"
  # Copy sd-boot to BOTH the systemd path and the removable fallback, so it boots
  # even if bootctl couldn't write an NVRAM entry (common inside a chroot).
  cp -f "$SDBOOT" /boot/EFI/systemd/systemd-bootx64.efi
  cp -f "$SDBOOT" /boot/EFI/BOOT/BOOTX64.EFI
  cat > /boot/loader/loader.conf <<EOF
default exherbo
timeout 3
editor  yes
EOF
  if [ -n "$KVER" ] && [ -n "$ROOT_UUID" ]; then
    cat > /boot/loader/entries/exherbo.conf <<EOF
title   Exherbo
linux   /vmlinuz-${KVER}
options root=UUID=${ROOT_UUID} rw
EOF
    printf '%bsystemd-boot installed (+ removable \\EFI\\BOOT\\BOOTX64.EFI).%b\n' "$GRN" "$NC"
  else
    warn "boot entry not written (KVER='$KVER' ROOT_UUID='$ROOT_UUID')"
  fi
elif [ -n "$KVER" ] && [ -d "/usr/src/linux-${KVER}" ] && [ -n "$ROOT_UUID" ]; then
  warn "no systemd-boot binary here — using a direct EFISTUB boot instead"
  # The kernel is a valid EFI application. Bake the cmdline in (the removable
  # path can't pass one) and drop the kernel straight at \EFI\BOOT\BOOTX64.EFI.
  cd "/usr/src/linux-${KVER}"
  ./scripts/config -e EFI_STUB -e CMDLINE_BOOL --set-str CMDLINE "root=UUID=${ROOT_UUID} rw"
  make olddefconfig
  make -j"$(nproc)" bzImage
  cp -f arch/x86/boot/bzImage /boot/EFI/BOOT/BOOTX64.EFI
  cp -f arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"
  cd /
  printf '%bEFISTUB kernel installed at \\EFI\\BOOT\\BOOTX64.EFI (root=UUID=%s).%b\n' "$GRN" "$ROOT_UUID" "$NC"
else
  warn "no bootloader installed (KVER='$KVER' ROOT_UUID='$ROOT_UUID') — set one up by hand"
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
