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

# ── Firmware, kernel & initramfs ──────────────────────────────────────────────
header "Building the kernel (sys-kernel/linux) — this is the long part"
$RESOLVE sys-kernel/linux sys-firmware/linux-firmware sys-kernel/dracut || \
  warn "kernel/firmware resolve had issues — inspect the cave output"

KSRC="$(ls -d /usr/src/linux-* 2>/dev/null | sort -V | tail -1 || true)"
if [ -n "$KSRC" ] && [ -d "$KSRC" ]; then
  cd "$KSRC"
  # defconfig is generic + bootable. For this MacBook, enable i915 + SIMPLEDRM and
  # trim with `make menuconfig` before `make`.
  make defconfig
  make -j"$(nproc)"
  make modules_install
  make install
  KVER="$(make -s kernelrelease 2>/dev/null || basename "$KSRC" | sed 's/^linux-//')"
  command -v dracut >/dev/null 2>&1 && dracut --force "/boot/initramfs-${KVER}.img" "$KVER" || \
    warn "dracut not available — generate an initramfs before rebooting"
  cd /
else
  warn "kernel sources not found under /usr/src — build a kernel by hand"
fi

# ── Bootloader (UEFI, GRUB --removable so a Mac's firmware finds it) ──────────
header "Installing GRUB (UEFI)"
$RESOLVE sys-boot/grub sys-boot/efibootmgr || warn "grub/efibootmgr resolve failed"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Exherbo --removable || \
  warn "grub-install failed — check /boot is the mounted ESP"
grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig failed"

# ── Privilege escalation ──────────────────────────────────────────────────────
header "Privilege escalation (${PRIV_ESC})"
if [ "$PRIV_ESC" = "doas" ]; then
  $RESOLVE app-admin/doas || warn "install doas by hand: cave resolve -x app-admin/doas"
  echo "permit persist :wheel" > /etc/doas.conf && chmod 0400 /etc/doas.conf
else
  $RESOLVE app-admin/sudo || warn "install sudo by hand"
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
