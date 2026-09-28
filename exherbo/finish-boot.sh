#!/usr/bin/env bash
# =============================================================================
# Finish an ALREADY-installed Exherbo: build ONLY the kernel + bootloader and
# skip everything else (system config, cave sync, networking, doas). For when
# the base system is in place and you just need the box to actually boot.
#
# Run from a live environment as root:
#   DISK=/dev/vda ./finish-boot.sh          # VM (virtio disk)
#   DISK=/dev/sda ./finish-boot.sh          # real MacBook
#   KVER=7.2.8   DISK=/dev/vda ./finish-boot.sh   # pin a kernel version
#   SLIM=1       DISK=/dev/vda ./finish-boot.sh   # fast build: no modules, VM
#                                                   essentials only (~10 min vs ~45)
# =============================================================================
set -euo pipefail
SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

RED='\033[0;31m'; GRN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }
is_mounted() { mountpoint -q "$1" 2>/dev/null || grep -q " $1 " /proc/mounts 2>/dev/null; }

# Self-update so you always run the latest kernel/bootloader logic.
if [[ -z "${FB_SELFUPDATED:-}" ]] && command -v git >/dev/null 2>&1 \
   && git -C "$SELF_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$SELF_DIR" pull --ff-only >/dev/null 2>&1; then
    export FB_SELFUPDATED=1; exec "$SELF_DIR/$(basename "$0")" "$@"
  fi
fi

DISK="${DISK:-/dev/vda}"
MNT=/mnt/exherbo
[[ $EUID -eq 0 ]] || die "run as root"
[[ -b "$DISK" ]]  || die "$DISK is not a block device"
case "$DISK" in *[0-9]) P="${DISK}p" ;; *) P="${DISK}" ;; esac
EFI="${P}1"; ROOT="${P}3"
# The root spec baked into the boot cmdline. WITHOUT an initramfs the kernel can
# NOT resolve a filesystem UUID= — only PARTUUID= (GPT) or a device node. Get the
# GPT PARTUUID here in the live env, where blkid is reliable.
ROOT_PARTUUID="$(blkid -s PARTUUID -o value "$ROOT" 2>/dev/null || true)"

# ── Mount the installed system + pseudo-filesystems (idempotent) ──────────────
header "Mounting the installed system on ${ROOT}"
mkdir -p "$MNT"
is_mounted "$MNT"      || mount "$ROOT" "$MNT"
[[ -d "$MNT/etc/paludis" || -d "$MNT/var/db/paludis" ]] || \
  die "no Exherbo install found on $ROOT — run ./install.sh first"
mkdir -p "$MNT/boot"
is_mounted "$MNT/boot" || mount "$EFI" "$MNT/boot" || die "couldn't mount the ESP ($EFI) at $MNT/boot"
cp -L /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true
is_mounted "$MNT/dev"  || { mount --rbind /dev  "$MNT/dev"  && mount --make-rslave "$MNT/dev"; }
is_mounted "$MNT/sys"  || { mount --rbind /sys  "$MNT/sys"  && mount --make-rslave "$MNT/sys"; }
is_mounted "$MNT/proc" || mount -t proc none "$MNT/proc"
is_mounted "$MNT/run"  || { mount --rbind /run  "$MNT/run"  && mount --make-rslave "$MNT/run" || true; }

# ── The in-chroot kernel + bootloader phase ──────────────────────────────────
cat > "$MNT/kernel-boot.sh" <<'CHROOT'
#!/usr/bin/env bash
set -eu
YEL='\033[0;33m'; CYAN='\033[0;36m'; GRN='\033[0;32m'; NC='\033[0m'
header() { printf '\n%b── %s %b\n' "$CYAN" "$*" "$NC"; }
warn()   { printf '%b! %s%b\n' "$YEL" "$*" "$NC"; }
source /etc/profile 2>/dev/null || true
RESOLVE="cave resolve -x --continue-on-failure if-independent"
fetch()   { if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"; else wget -qO- "$1"; fi; }
dl_file() { if command -v curl >/dev/null 2>&1; then curl -fL# -o "$2" "$1"; else wget -O "$2" "$1"; fi; }

header "Firmware + kernel build tools"
$RESOLVE linux-firmware || warn "linux-firmware resolve failed"
$RESOLVE bc flex bison 2>/dev/null || true

KVER="${KVER:-$(fetch https://www.kernel.org/finger_banner 2>/dev/null | awk '/latest stable version/{print $NF; exit}')}"
KVER="${KVER:-7.2.8}"; KMAJ="${KVER%%.*}"
cd /usr/src
if [ ! -d "linux-${KVER}" ]; then
  header "Fetching linux-${KVER}"
  if dl_file "https://cdn.kernel.org/pub/linux/kernel/v${KMAJ}.x/linux-${KVER}.tar.xz" "linux-${KVER}.tar.xz"; then
    tar xf "linux-${KVER}.tar.xz" && rm -f "linux-${KVER}.tar.xz"
  else
    warn "kernel download failed"; exit 1
  fi
fi
cd "linux-${KVER}"
# defconfig + the KVM-guest fragment (virtio, paravirt, guest console).
make defconfig kvm_guest.config
if [ "${SLIM:-}" = "1" ]; then
  header "Building linux-${KVER} — SLIM (no modules, VM essentials; fast)"
  # Modules are the bulk of the build — drop them entirely and force IN just the
  # drivers we actually need: disk, fs, and a simple framebuffer console so the
  # QEMU window still shows output (no udev-loaded modules exist to bring it up).
  ./scripts/config -d MODULES \
    -e EXT4_FS -e VFAT_FS -e FAT_FS -e NLS_CODEPAGE_437 -e NLS_ISO8859_1 -e NLS_ASCII \
    -e VIRTIO -e VIRTIO_PCI -e VIRTIO_BLK -e VIRTIO_NET -e VIRTIO_CONSOLE -e VIRTIO_BALLOON \
    -e SATA_AHCI -e ATA -e ATA_PIIX -e BLK_DEV_NVME -e USB_STORAGE \
    -e SYSFB_SIMPLEFB -e DRM -e DRM_SIMPLEDRM -e DRM_FBDEV_EMULATION \
    -e FRAMEBUFFER_CONSOLE -e VT -e VT_CONSOLE -e EFI -e EFI_STUB
else
  header "Building linux-${KVER} (full defconfig — the long part)"
  # Disk/fs drivers the fragment doesn't cover, so it also boots real hardware.
  ./scripts/config \
    -e SATA_AHCI -e ATA -e ATA_PIIX -e BLK_DEV_NVME \
    -e EXT4_FS -e VFAT_FS -e FAT_FS \
    -e NLS_CODEPAGE_437 -e NLS_ISO8859_1 -e USB_STORAGE
fi
make olddefconfig
make -j"$(nproc)"
make modules_install 2>/dev/null || true
cp -f arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"

header "Installing the bootloader"
# No initramfs → the kernel resolves root= itself and only understands PARTUUID=
# (GPT) or a device node, NOT a filesystem UUID=. Prefer PARTUUID, fall back to
# the device node.
ROOT_SPEC="${ROOT_PARTUUID:+PARTUUID=${ROOT_PARTUUID}}"
[ -z "$ROOT_SPEC" ] && ROOT_SPEC="${ROOT_DEV:-/dev/vda3}"
echo "root spec for the boot cmdline: root=${ROOT_SPEC}"
mkdir -p /boot/EFI/BOOT /boot/EFI/systemd /boot/loader/entries
SDBOOT="$(find /usr -name 'systemd-bootx64.efi' 2>/dev/null | head -1)"
if [ -n "$SDBOOT" ]; then
  bootctl --esp-path=/boot install || warn "bootctl error — using manual copy"
  cp -f "$SDBOOT" /boot/EFI/systemd/systemd-bootx64.efi
  cp -f "$SDBOOT" /boot/EFI/BOOT/BOOTX64.EFI
  printf 'default exherbo\ntimeout 3\neditor  yes\n' > /boot/loader/loader.conf
  printf 'title   Exherbo\nlinux   /vmlinuz-%s\noptions root=%s rw\n' "$KVER" "$ROOT_SPEC" \
    > /boot/loader/entries/exherbo.conf
  printf '%bsystemd-boot installed (+ removable \\EFI\\BOOT\\BOOTX64.EFI).%b\n' "$GRN" "$NC"
else
  warn "no systemd-boot binary — using a direct EFISTUB boot"
  ./scripts/config -e EFI_STUB -e CMDLINE_BOOL --set-str CMDLINE "root=${ROOT_SPEC} rw"
  make olddefconfig
  make -j"$(nproc)" bzImage
  cp -f arch/x86/boot/bzImage /boot/EFI/BOOT/BOOTX64.EFI
  cp -f arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"
  printf '%bEFISTUB kernel installed at \\EFI\\BOOT\\BOOTX64.EFI (root=%s).%b\n' "$GRN" "$ROOT_SPEC" "$NC"
fi
CHROOT
chmod +x "$MNT/kernel-boot.sh"

header "Entering chroot: kernel + bootloader only"
if env -i HOME=/root TERM="${TERM:-linux}" KVER="${KVER:-}" SLIM="${SLIM:-}" \
     ROOT_PARTUUID="${ROOT_PARTUUID:-}" ROOT_DEV="$ROOT" \
     "$(command -v chroot)" "$MNT" /bin/bash -lc '/kernel-boot.sh'; then
  header "Done"
  echo -e "${GRN}Kernel + bootloader installed. Reboot into it:${NC}"
  echo "  swapoff -a; umount -R ${MNT}; then boot the disk (./run-vm.sh with no args)"
else
  die "kernel/bootloader step failed — see the output above"
fi
