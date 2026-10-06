#!/usr/bin/env bash
# =============================================================================
# Build/refresh the kernel + bootloader for THIS Exherbo system. Runs as root,
# both ways:
#   - ON the booted system, to UPDATE the kernel to the latest stable:
#       doas ./kernel-boot.sh
#   - inside the installer chroot (finish-boot.sh / install.sh call it here).
#
# It downloads the latest stable kernel from kernel.org, builds it with the
# disk/fs drivers compiled IN (no initramfs), installs the bootloader
# (systemd-boot, else a direct EFISTUB) with root=PARTUUID=, and leaves the
# previous kernel in place until you reboot.
#
# Env: KVER=x.y.z  pin a version
#      ROOT_PARTUUID= / ROOT_DEV=  override root detection (finish-boot sets these)
# =============================================================================
set -eu
YEL='\033[0;33m'; CYAN='\033[0;36m'; GRN='\033[0;32m'; NC='\033[0m'
header() { printf '\n%b── %s %b\n' "$CYAN" "$*" "$NC"; }
warn()   { printf '%b! %s%b\n' "$YEL" "$*" "$NC"; }
[ "$(id -u)" -eq 0 ] || { printf 'run as root (doas ./kernel-boot.sh)\n' >&2; exit 1; }
source /etc/profile 2>/dev/null || true

RESOLVE="cave resolve -x --continue-on-failure if-independent"
fetch()   { if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"; else wget -qO- "$1"; fi; }
dl_file() { if command -v curl >/dev/null 2>&1; then curl -fL# -o "$2" "$1"; else wget -O "$2" "$1"; fi; }

# ── Which device is our root? Used for root=PARTUUID= (kernel-native, no initrd) ─
ROOT_DEV="${ROOT_DEV:-$(findmnt -no SOURCE / 2>/dev/null || true)}"
ROOT_PARTUUID="${ROOT_PARTUUID:-$(blkid -s PARTUUID -o value "$ROOT_DEV" 2>/dev/null || true)}"
ROOT_SPEC="${ROOT_PARTUUID:+PARTUUID=${ROOT_PARTUUID}}"
[ -z "$ROOT_SPEC" ] && ROOT_SPEC="${ROOT_DEV:-/dev/vda3}"

# ── Firmware + kernel build tools ─────────────────────────────────────────────
header "Firmware + kernel build tools"
$RESOLVE linux-firmware 2>/dev/null || warn "linux-firmware resolve failed (optional)"
$RESOLVE bc flex bison 2>/dev/null || true

# ── Fetch the kernel source ───────────────────────────────────────────────────
KVER="${KVER:-$(fetch https://www.kernel.org/finger_banner 2>/dev/null | awk '/latest stable version/{print $NF; exit}')}"
KVER="${KVER:-7.2.8}"; KMAJ="${KVER%%.*}"
cd /usr/src
if [ ! -d "linux-${KVER}" ]; then
  header "Fetching linux-${KVER}"
  if dl_file "https://cdn.kernel.org/pub/linux/kernel/v${KMAJ}.x/linux-${KVER}.tar.xz" "linux-${KVER}.tar.xz"; then
    tar xf "linux-${KVER}.tar.xz" && rm -f "linux-${KVER}.tar.xz"
  else
    warn "kernel download failed (no curl/wget, or network)"; exit 1
  fi
fi
cd "linux-${KVER}"

# Atomic install: copy to a temp then rename, so an interrupted or failed write
# (e.g. a full disk) never leaves a truncated kernel/loader — the previous one
# survives instead of bricking the boot.
atomic_cp() { cp -f "$1" "$2.tmp" && { sync 2>/dev/null || true; mv -f "$2.tmp" "$2"; }; }

# Free space + drop stale objects: a previous (especially full) build can fill a
# small VM disk, which is what corrupts the loader mid-write. Start compact.
header "Cleaning the build tree (frees space from any previous build)"
make clean >/dev/null 2>&1 || true

# ── Configure ─────────────────────────────────────────────────────────────────
# defconfig + the KVM-guest fragment (virtio, paravirt, guest console).
make defconfig kvm_guest.config
header "Configuring linux-${KVER} (lean, no-modules build)"
# No loadable modules — they're the bulk of the build and the disk-filler that
# bricked the full build. Force IN exactly what's needed to boot with no
# initramfs: virtio (VM) + AHCI/NVMe/USB (real disks), ext4/vfat, a framebuffer
# console (virtio-gpu/simpledrm), PS/2 + evdev input, and EFISTUB.
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
atomic_cp arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"

# ── Bootloader (no initramfs → root= must be PARTUUID= or a device, NOT fs UUID) ─
header "Installing the bootloader"
echo "root spec for the boot cmdline: root=${ROOT_SPEC}"
mkdir -p /boot/EFI/BOOT /boot/EFI/systemd /boot/loader/entries
SDBOOT="$(find /usr -name 'systemd-bootx64.efi' 2>/dev/null | head -1)"
if [ -n "$SDBOOT" ]; then
  bootctl --esp-path=/boot install || warn "bootctl error — using manual copy"
  cp -f "$SDBOOT" /boot/EFI/systemd/systemd-bootx64.efi
  atomic_cp "$SDBOOT" /boot/EFI/BOOT/BOOTX64.EFI
  printf 'default exherbo\ntimeout 3\neditor  yes\n' > /boot/loader/loader.conf
  printf 'title   Exherbo\nlinux   /vmlinuz-%s\noptions root=%s rw\n' "$KVER" "$ROOT_SPEC" \
    > /boot/loader/entries/exherbo.conf
  printf '%bsystemd-boot installed for linux-%s (+ removable \\EFI\\BOOT\\BOOTX64.EFI).%b\n' "$GRN" "$KVER" "$NC"
else
  warn "no systemd-boot binary — using a direct EFISTUB boot"
  ./scripts/config -e EFI_STUB -e CMDLINE_BOOL --set-str CMDLINE "root=${ROOT_SPEC} rw"
  make olddefconfig
  make -j"$(nproc)" bzImage
  atomic_cp arch/x86/boot/bzImage /boot/EFI/BOOT/BOOTX64.EFI
  atomic_cp arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"
  printf '%bEFISTUB linux-%s installed at \\EFI\\BOOT\\BOOTX64.EFI (root=%s).%b\n' "$GRN" "$KVER" "$ROOT_SPEC" "$NC"
fi

header "Kernel ${KVER} ready — reboot to run it"
