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
header "Building linux-${KVER} (the long part)"
# defconfig + the KVM-guest fragment (virtio, paravirt, guest console). Plus the
# disk/fs drivers the fragment doesn't cover, so it also boots real hardware.
make defconfig kvm_guest.config
./scripts/config \
  -e SATA_AHCI -e ATA -e ATA_PIIX -e BLK_DEV_NVME \
  -e EXT4_FS -e VFAT_FS -e FAT_FS \
  -e NLS_CODEPAGE_437 -e NLS_ISO8859_1 -e USB_STORAGE
make olddefconfig
make -j"$(nproc)"
make modules_install
cp -f arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"

header "Installing the bootloader"
ROOT_UUID="$(findmnt -no UUID / 2>/dev/null || true)"
[ -z "$ROOT_UUID" ] && ROOT_UUID="$(blkid -s UUID -o value "$(findmnt -no SOURCE / 2>/dev/null)" 2>/dev/null || true)"
mkdir -p /boot/EFI/BOOT /boot/EFI/systemd /boot/loader/entries
SDBOOT="$(find /usr -name 'systemd-bootx64.efi' 2>/dev/null | head -1)"
if [ -n "$SDBOOT" ]; then
  bootctl --esp-path=/boot install || warn "bootctl error — using manual copy"
  cp -f "$SDBOOT" /boot/EFI/systemd/systemd-bootx64.efi
  cp -f "$SDBOOT" /boot/EFI/BOOT/BOOTX64.EFI
  printf 'default exherbo\ntimeout 3\neditor  yes\n' > /boot/loader/loader.conf
  printf 'title   Exherbo\nlinux   /vmlinuz-%s\noptions root=UUID=%s rw\n' "$KVER" "$ROOT_UUID" \
    > /boot/loader/entries/exherbo.conf
  printf '%bsystemd-boot installed (+ removable \\EFI\\BOOT\\BOOTX64.EFI).%b\n' "$GRN" "$NC"
elif [ -n "$ROOT_UUID" ]; then
  warn "no systemd-boot binary — using a direct EFISTUB boot"
  ./scripts/config -e EFI_STUB -e CMDLINE_BOOL --set-str CMDLINE "root=UUID=${ROOT_UUID} rw"
  make olddefconfig
  make -j"$(nproc)" bzImage
  cp -f arch/x86/boot/bzImage /boot/EFI/BOOT/BOOTX64.EFI
  cp -f arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"
  printf '%bEFISTUB kernel installed at \\EFI\\BOOT\\BOOTX64.EFI (root=UUID=%s).%b\n' "$GRN" "$ROOT_UUID" "$NC"
else
  warn "ROOT_UUID empty — bootloader NOT installed"; exit 1
fi
CHROOT
chmod +x "$MNT/kernel-boot.sh"

header "Entering chroot: kernel + bootloader only"
if env -i HOME=/root TERM="${TERM:-linux}" KVER="${KVER:-}" \
     "$(command -v chroot)" "$MNT" /bin/bash -lc '/kernel-boot.sh'; then
  header "Done"
  echo -e "${GRN}Kernel + bootloader installed. Reboot into it:${NC}"
  echo "  swapoff -a; umount -R ${MNT}; then boot the disk (./run-vm.sh with no args)"
else
  die "kernel/bootloader step failed — see the output above"
fi
