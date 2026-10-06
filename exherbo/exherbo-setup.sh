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
  # defconfig + the KVM-guest fragment (virtio, paravirt, guest console).
  make defconfig kvm_guest.config
  # Lean, no-modules build: modules are the bulk of the compile and a disk-filler,
  # so drop them and force IN just what's needed to boot with no initramfs —
  # virtio (VM) + AHCI/NVMe/USB (real disks), ext4/vfat, a framebuffer console,
  # PS/2 + evdev input, EFISTUB.
  ./scripts/config -d MODULES \
    -e EXT4_FS -e VFAT_FS -e FAT_FS -e NLS_CODEPAGE_437 -e NLS_ISO8859_1 -e NLS_ASCII \
    -e VIRTIO -e VIRTIO_PCI -e VIRTIO_BLK -e VIRTIO_NET -e VIRTIO_CONSOLE -e VIRTIO_BALLOON \
    -e SATA_AHCI -e ATA -e ATA_PIIX -e BLK_DEV_NVME -e USB_STORAGE \
    -e SYSFB_SIMPLEFB -e DRM -e DRM_SIMPLEDRM -e DRM_FBDEV_EMULATION \
    -e DRM_VIRTIO_GPU -e DRM_KMS_HELPER \
    -e INPUT_EVDEV -e SERIO_I8042 -e INPUT_KEYBOARD -e KEYBOARD_ATKBD \
    -e INPUT_MOUSE -e MOUSE_PS2 -e INPUT_MOUSEDEV \
    -e FRAMEBUFFER_CONSOLE -e VT -e VT_CONSOLE -e EFI -e EFI_STUB \
    -e PARTITION_ADVANCED -e EFI_PARTITION -e BLK_DEV -e BLOCK
  make olddefconfig
  make -j"$(nproc)"
  make modules_install 2>/dev/null || true
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
# No initramfs → the kernel resolves root= itself and only understands PARTUUID=
# (GPT) or a device node, NOT a filesystem UUID=. Derive the GPT PARTUUID of the
# device backing / and use that.
ROOT_DEV="$(findmnt -no SOURCE / 2>/dev/null || true)"
ROOT_PARTUUID="$(blkid -s PARTUUID -o value "$ROOT_DEV" 2>/dev/null || true)"
ROOT_SPEC="${ROOT_PARTUUID:+PARTUUID=${ROOT_PARTUUID}}"
[ -z "$ROOT_SPEC" ] && ROOT_SPEC="${ROOT_DEV:-/dev/vda3}"
echo "root spec for the boot cmdline: root=${ROOT_SPEC}"
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
  if [ -n "$KVER" ]; then
    cat > /boot/loader/entries/exherbo.conf <<EOF
title   Exherbo
linux   /vmlinuz-${KVER}
options root=${ROOT_SPEC} rw
EOF
    printf '%bsystemd-boot installed (+ removable \\EFI\\BOOT\\BOOTX64.EFI).%b\n' "$GRN" "$NC"
  else
    warn "boot entry not written (KVER empty)"
  fi
elif [ -n "$KVER" ] && [ -d "/usr/src/linux-${KVER}" ]; then
  warn "no systemd-boot binary here — using a direct EFISTUB boot instead"
  # The kernel is a valid EFI application. Bake the cmdline in (the removable
  # path can't pass one) and drop the kernel straight at \EFI\BOOT\BOOTX64.EFI.
  cd "/usr/src/linux-${KVER}"
  ./scripts/config -e EFI_STUB -e CMDLINE_BOOL --set-str CMDLINE "root=${ROOT_SPEC} rw"
  make olddefconfig
  make -j"$(nproc)" bzImage
  cp -f arch/x86/boot/bzImage /boot/EFI/BOOT/BOOTX64.EFI
  cp -f arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"
  cd /
  printf '%bEFISTUB kernel installed at \\EFI\\BOOT\\BOOTX64.EFI (root=%s).%b\n' "$GRN" "$ROOT_SPEC" "$NC"
else
  warn "no bootloader installed (KVER='$KVER') — set one up by hand"
fi

# ── Privilege escalation ──────────────────────────────────────────────────────
header "Privilege escalation (${PRIV_ESC})"
if [ "$PRIV_ESC" = "doas" ]; then
  # doas isn't in arbor — it's in the third-party 'somasis' repo. Try that first;
  # if the repo won't resolve (common), build the tiny doas port from source.
  $RESOLVE repository/somasis 2>/dev/null && cave sync somasis 2>/dev/null || true
  if ! { $RESOLVE app-admin/doas 2>/dev/null && command -v doas >/dev/null 2>&1; }; then
    warn "somasis/doas unavailable — building doas from source (slicer69/doas)"
    ( cd /usr/src && rm -rf doas-master doas.tgz \
      && dl_file "https://codeload.github.com/slicer69/doas/tar.gz/refs/heads/master" doas.tgz \
      && tar xf doas.tgz && cd doas-master && make && make install ) \
      || warn "doas source build failed — you'll have no doas!"
  fi
  if command -v doas >/dev/null 2>&1; then
    echo "permit persist :wheel" > /etc/doas.conf && chmod 0400 /etc/doas.conf
    printf '%bdoas configured (permit persist :wheel).%b\n' "$GRN" "$NC"
  fi
else
  $RESOLVE sudo || warn "install sudo by hand"
  mkdir -p /etc/sudoers.d
  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
fi

# ── fastfetch (third-party 'tombriden' repo — non-fatal if unavailable) ───────
header "Installing fastfetch"
$RESOLVE repository/tombriden 2>/dev/null && cave sync tombriden 2>/dev/null || true
$RESOLVE fastfetch 2>/dev/null || warn "fastfetch skipped (tombriden repo didn't resolve)"

# ── Users & passwords ─────────────────────────────────────────────────────────
header "Set the root password"
passwd root
USERNAME="${USERNAME:-legend}"
printf '%bRegular user name? (default: %s, '\''-'\'' to skip):%b ' "$YEL" "$USERNAME" "$NC"
read -r ANS || ANS=""
if [ "$ANS" = "-" ]; then USERNAME=""; else USERNAME="${ANS:-$USERNAME}"; fi
if [ -n "$USERNAME" ]; then
  groupadd -f wheel 2>/dev/null || true
  useradd -mG wheel -s /bin/bash "$USERNAME" 2>/dev/null || true
  printf 'set %s password:\n' "$USERNAME"; passwd "$USERNAME" || true
fi

# ── Optional: bspwm desktop (Xorg — a big source build) ───────────────────────
if [ "${INSTALL_WM:-}" = "true" ]; then
  header "Installing the bspwm desktop (Xorg + bspwm — long compile)"
  $RESOLVE xorg-server xinit xf86-input-libinput bspwm sxhkd xterm \
    || warn "some WM packages didn't resolve — finish by hand with cave"
  if [ -n "$USERNAME" ] && [ -d "/home/$USERNAME" ]; then
    UH="/home/$USERNAME"
    mkdir -p "$UH/.config/bspwm" "$UH/.config/sxhkd"
    cat > "$UH/.config/bspwm/bspwmrc" <<'BSPWM'
#!/bin/sh
bspc monitor -d 1 2 3 4 5
bspc config border_width          2
bspc config window_gap            8
bspc config focus_follows_pointer true
BSPWM
    chmod +x "$UH/.config/bspwm/bspwmrc"
    cat > "$UH/.config/sxhkd/sxhkdrc" <<'SXHKD'
super + Return
	xterm
super + w
	bspc node -c
super + {1-5}
	bspc desktop -f '^{1-5}'
super + shift + q
	bspc quit
SXHKD
    printf 'sxhkd &\nexec bspwm\n' > "$UH/.xinitrc"
    chown -R "$USERNAME:$USERNAME" "$UH/.config" "$UH/.xinitrc" 2>/dev/null || true
    printf '%bDesktop ready — log in as %s and run: startx  (super+Return = terminal)%b\n' "$GRN" "$USERNAME" "$NC"
  fi
fi

header "chroot setup complete"
printf '%bExit the chroot, then: swapoff -a, umount -R the target, reboot.%b\n' "$GRN" "$NC"
printf 'Wifi on the real MacBook: build net-wireless/broadcom-sta and load '\''wl'\''.\n'
