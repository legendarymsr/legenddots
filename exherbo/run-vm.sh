#!/usr/bin/env bash
# =============================================================================
# legend's Exherbo-in-a-VM launcher. One command, does everything:
#   - installs qemu + OVMF firmware if missing (app-emulation/qemu,
#     sys-firmware/edk2-bin), sets QEMU_SOFTMMU_TARGETS
#   - adds legend to the kvm group and activates it for this session (no
#     re-login needed) via sg
#   - makes the disk + writable UEFI NVRAM on first run
#   - auto-downloads the Gentoo minimal ISO the first time and boots the
#     installer; boots the installed system afterwards
#
#   ./run-vm.sh            first run -> INSTALL (inside: DISK=/dev/vda ./install.sh)
#                          after     -> BOOT the installed system
#   ./run-vm.sh install    force install mode again
#   ./run-vm.sh repair     BOOT WON'T WORK? direct-boot the disk's kernel via
#                          -kernel (bypasses a broken/missing ESP bootloader),
#                          and best-effort restore \EFI\BOOT\BOOTX64.EFI. One
#                          command, no live CD. Needs qemu-nbd + doas.
#   ./run-vm.sh /path.iso  install with a specific ISO
#
# Tunables (env): VM_DIR DISK_SIZE MEM CPUS FW_CODE FW_VARS DISPLAY_TYPE
#                 ISO_DEFAULT ISO_URL
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

# Must run as your user, NOT via doas/root: it calls doas itself where it needs
# root, and the GUI needs your own X session (gtk init fails as root).
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  die "don't run this with doas/root — run it as legend. It uses doas itself for emerge/kvm; the VM window needs your X session."
fi

USER_NAME="legend"
VM_DIR="${VM_DIR:-$HOME/exherbo-vm}"
DISK="$VM_DIR/exherbo.qcow2"
DISK_SIZE="${DISK_SIZE:-20G}"
MEM="${MEM:-4G}"                       # 8GB host: 4G guest leaves the host room
CPUS="${CPUS:-$(nproc)}"               # i5-4250U = 4 threads
SSH_PORT="${SSH_PORT:-2222}"           # host port -> guest :22  (ssh -p 2222 root@localhost)
ISO_DEFAULT="${ISO_DEFAULT:-$HOME/live.iso}"
# Gentoo minimal install ISO (UEFI-bootable). Dated autobuilds rotate off the
# mirror eventually — if this 404s, bump the date or pass your own ISO / ISO_URL.
ISO_URL="${ISO_URL:-https://distfiles.gentoo.org/releases/amd64/autobuilds/20260913T163055Z/install-amd64-minimal-20260913T163055Z.iso}"

FW_CODE="${FW_CODE:-}"; FW_VARS="${FW_VARS:-}"

detect_fw() {
  [[ -n "$FW_CODE" ]] && return 0
  local d c
  for d in /usr/share/edk2/ovmf /usr/share/edk2-ovmf /usr/share/OVMF /usr/share/qemu /usr/share/edk2; do
    for c in OVMF_CODE.fd OVMF_CODE.4m.fd OVMF_CODE_4M.fd; do
      [[ -f "$d/$c" ]] && { FW_CODE="$d/$c"; return 0; }
    done
  done
  return 1
}

# ── Install qemu + firmware if missing, add legend to kvm group ───────────────
ensure_prereqs() {
  local need=()
  command -v qemu-system-x86_64 >/dev/null 2>&1 || need+=("app-emulation/qemu")
  detect_fw || need+=("sys-firmware/edk2-bin")
  if (( ${#need[@]} )); then
    command -v doas >/dev/null 2>&1 || die "need doas to install: ${need[*]}"
    header "Installing prerequisites: ${need[*]}"
    grep -q 'QEMU_SOFTMMU_TARGETS' /etc/portage/make.conf 2>/dev/null || \
      echo 'QEMU_SOFTMMU_TARGETS="x86_64"' | doas tee -a /etc/portage/make.conf >/dev/null
    # make sure a fresh qemu is built with a working GUI display (gtk) + the target
    if printf '%s\n' "${need[@]}" | grep -q 'qemu'; then
      local pu=/etc/portage/package.use
      [[ -d "$pu" ]] && pu="$pu/qemu-vm"
      grep -qs 'app-emulation/qemu .*gtk' "$pu" 2>/dev/null || \
        echo 'app-emulation/qemu gtk vnc' | doas tee -a "$pu" >/dev/null
    fi
    doas emerge -avN "${need[@]}" || die "emerge failed — install ${need[*]} by hand"
    FW_CODE=""; detect_fw || true
  fi
  if ! getent group kvm 2>/dev/null | grep -qw "$USER_NAME"; then
    header "Adding $USER_NAME to the kvm group"
    doas usermod -aG kvm "$USER_NAME"
  fi
}

# ── Make sure /dev/kvm is usable THIS session (sg avoids a re-login) ──────────
ensure_kvm_access() {
  [[ -w /dev/kvm ]] && return 0
  if getent group kvm 2>/dev/null | grep -qw "$USER_NAME"; then
    if [[ -z "${RUNVM_SG:-}" ]] && command -v sg >/dev/null 2>&1; then
      warn "activating the kvm group for this session (no re-login needed)…"
      export RUNVM_SG=1
      exec sg kvm -c "$(printf '%q ' "$0" "$@")"
    fi
    warn "you're in the kvm group but this shell predates it — log out/in, then re-run ./run-vm.sh"
    exit 0
  fi
  warn "no /dev/kvm access — running WITHOUT acceleration (slow)"
}

ensure_prereqs
ensure_kvm_access "$@"

command -v qemu-img >/dev/null 2>&1 || die "qemu-img not found — app-emulation/qemu didn't install right"
mkdir -p "$VM_DIR"

# ── Mode: install vs boot vs repair ───────────────────────────────────────────
ARG="${1:-}"; ISO=""
if [[ "$ARG" == "install" ]]; then MODE="install"; ISO="${2:-}"
elif [[ "$ARG" == "repair" ]];  then MODE="repair"
elif [[ -n "$ARG" ]];       then MODE="install"; ISO="$ARG"
elif [[ -f "$DISK" ]];      then MODE="boot"
else                             MODE="install"
fi

# ── Firmware (installed by now) + writable NVRAM copy ────────────────────────
detect_fw || die "OVMF firmware still not found — set FW_CODE=/path/OVMF_CODE.fd"
if [[ -z "$FW_VARS" ]]; then
  FW_VARS="${FW_CODE/OVMF_CODE/OVMF_VARS}"
  [[ -f "$FW_VARS" ]] || FW_VARS="$(dirname "$FW_CODE")/OVMF_VARS.fd"
fi
[[ -f "$FW_VARS" ]] || die "OVMF_VARS not found next to $FW_CODE — set FW_VARS=/path/OVMF_VARS.fd"

NVRAM="$VM_DIR/OVMF_VARS.fd"
# In install mode, always reset the NVRAM to factory boot order — OVMF persists
# its BootOrder here, and a stale one makes it ignore the CD and fall through to
# the (empty) disk / PXE. A fresh copy boots the CD; boot mode keeps its NVRAM.
if [[ ! -f "$NVRAM" || "$MODE" == "install" ]]; then
  header "Resetting UEFI NVRAM -> $NVRAM (fresh firmware boot order)"
  cp "$FW_VARS" "$NVRAM"
fi
[[ -f "$DISK" ]]  || { header "Creating disk $DISK ($DISK_SIZE)"; qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"; }

# ── Repair mode: boot the disk directly via -kernel, bypassing a broken ESP
#    bootloader. Pull a kernel + the root PARTUUID out of the disk with qemu-nbd,
#    and best-effort restore \EFI\BOOT\BOOTX64.EFI so normal boot may work again.
REPAIR_KERNEL="$VM_DIR/repair-kernel"; REPAIR_ROOT=""
if [[ "$MODE" == "repair" ]]; then
  header "Repair — pulling a kernel out of $DISK to boot it directly"

  # ── Method 1: libguestfs — reads the disk image with NO root and NO nbd
  #    module (it spins up its own tiny appliance). The clean path; install with
  #    `doas emerge app-emulation/libguestfs` (Gentoo) / `libguestfs` elsewhere.
  if command -v guestfish >/dev/null 2>&1; then
    echo "  using libguestfs (no password, no nbd needed)"
    rm -f "$VM_DIR"/vmlinuz-* 2>/dev/null || true
    guestfish --ro -a "$DISK" run : mount /dev/sda1 / : glob copy-out '/vmlinuz-*' "$VM_DIR" >/dev/null 2>&1 || true
    K="$(ls -1t "$VM_DIR"/vmlinuz-* 2>/dev/null | head -1)"
    [[ -n "$K" ]] && mv -f "$K" "$REPAIR_KERNEL"
    REPAIR_ROOT="$(guestfish --ro -a "$DISK" run : part-get-gpt-guid /dev/sda 3 2>/dev/null | tr 'A-Z' 'a-z' | tr -cd '0-9a-f-')"
    [[ -f "$REPAIR_KERNEL" && -n "$REPAIR_ROOT" ]] && echo "  kernel: $(basename "$REPAIR_KERNEL")"
  fi

  # ── Method 2: qemu-nbd — needs the host `nbd` kernel MODULE + one doas
  #    password. Only tried if libguestfs didn't already do it.
  if [[ ! -f "$REPAIR_KERNEL" || -z "$REPAIR_ROOT" ]] \
     && command -v qemu-nbd >/dev/null 2>&1 && command -v doas >/dev/null 2>&1; then
    echo -e "  ${CYAN}qemu-nbd path — doas asks for YOUR login password (user ${USER_NAME}) once.${NC}"
    REPAIR_ROOT="$(doas env DISK="$DISK" VM_DIR="$VM_DIR" REPAIR_KERNEL="$REPAIR_KERNEL" USER_NAME="$USER_NAME" bash -c '
      set -u
      NBD=/dev/nbd0; MP="$VM_DIR/.esp"
      modprobe nbd max_part=8 2>/dev/null || { echo "  no nbd module in this host kernel" >&2; exit 0; }
      qemu-nbd --disconnect "$NBD" >/dev/null 2>&1 || true
      qemu-nbd --connect="$NBD" -f qcow2 "$DISK" 1>&2 || { echo "  qemu-nbd connect failed" >&2; exit 0; }
      sleep 1; partprobe "$NBD" 2>/dev/null || true; sleep 1
      mkdir -p "$MP"
      if mount "${NBD}p1" "$MP" 2>/dev/null; then
        K="$(ls -1t "$MP"/vmlinuz-* 2>/dev/null | head -1)"
        [ -z "$K" ] && [ -f "$MP/EFI/BOOT/BOOTX64.EFI" ] && K="$MP/EFI/BOOT/BOOTX64.EFI"
        if [ -n "$K" ]; then
          cp "$K" "$REPAIR_KERNEL" && chown "$USER_NAME" "$REPAIR_KERNEL"
          echo "  kernel: $(basename "$K")" >&2
          cp "$K" "$MP/EFI/BOOT/BOOTX64.EFI.new" 2>/dev/null \
            && mv -f "$MP/EFI/BOOT/BOOTX64.EFI.new" "$MP/EFI/BOOT/BOOTX64.EFI" 2>/dev/null \
            && echo "  restored BOOTX64.EFI" >&2
        fi
        umount "$MP" 2>/dev/null || true
      else
        echo "  could not mount the ESP (${NBD}p1)" >&2
      fi
      blkid -s PARTUUID -o value "${NBD}p3" 2>/dev/null
      qemu-nbd --disconnect "$NBD" >/dev/null 2>&1 || true
      rmdir "$MP" 2>/dev/null || true
    ')"
  fi

  if [[ ! -f "$REPAIR_KERNEL" || -z "$REPAIR_ROOT" ]]; then
    die "couldn't read a kernel from the disk (your host kernel has no nbd module). Either:
    • install libguestfs for a no-root, no-nbd repair:  doas emerge app-emulation/libguestfs
    • or rebuild via the CD (works with what you have):  ./run-vm.sh install
        then in the live CD:  SLIM=1 DISK=/dev/vda ./exherbo/finish-boot.sh"
  fi
  echo "  root=PARTUUID=$REPAIR_ROOT"
fi

# ── Install mode: get an ISO (download the default if missing) ────────────────
if [[ "$MODE" == "install" ]]; then
  [[ -n "$ISO" ]] || ISO="$ISO_DEFAULT"
  if [[ ! -f "$ISO" ]]; then
    if [[ "$ISO" == "$ISO_DEFAULT" ]]; then
      command -v curl >/dev/null 2>&1 || die "curl not found — needed to fetch the ISO"
      header "No ISO at $ISO — downloading Gentoo minimal"
      curl -fL# -o "$ISO" "$ISO_URL" || { rm -f "$ISO"; die "ISO download failed ($ISO_URL)"; }
    else
      die "ISO not found: $ISO"
    fi
  fi
fi

# ── Acceleration + display ────────────────────────────────────────────────────
if [[ -w /dev/kvm ]]; then ACCEL=(-enable-kvm -cpu host); else ACCEL=(-cpu qemu64); fi

DISPLAY_TYPE="${DISPLAY_TYPE:-}"
if [[ -z "$DISPLAY_TYPE" ]]; then
  for d in gtk sdl; do
    qemu-system-x86_64 -display help 2>/dev/null | grep -qw "$d" && { DISPLAY_TYPE="$d"; break; }
  done
fi
if [[ -n "$DISPLAY_TYPE" ]]; then
  DISP=(-vga virtio -display "$DISPLAY_TYPE")
else
  warn "no gtk/sdl display in this qemu build — using VNC on localhost:5900."
  DISP=(-vga virtio -display none -vnc :0)
fi

# ── Run ───────────────────────────────────────────────────────────────────────
ARGS=(
  "${ACCEL[@]}"
  -m "$MEM" -smp "$CPUS"
  -drive "if=pflash,format=raw,readonly=on,file=$FW_CODE"
  -drive "if=pflash,format=raw,file=$NVRAM"
  -drive "file=$DISK,if=virtio"
  -netdev "user,id=n0,hostfwd=tcp::${SSH_PORT}-:22" -device virtio-net,netdev=n0
  "${DISP[@]}"
)
if [[ "$MODE" == "install" ]]; then
  ARGS+=(-cdrom "$ISO" -boot menu=on)
  header "Install mode — booting $ISO"
  echo -e "  ${GREEN}Inside the VM, run:${NC}  DISK=/dev/vda ./install.sh"
elif [[ "$MODE" == "repair" ]]; then
  ARGS+=(-kernel "$REPAIR_KERNEL" -append "root=PARTUUID=$REPAIR_ROOT rw")
  header "Repair mode — direct-booting the installed system (bypassing the ESP loader)"
else
  header "Boot mode — starting the installed system on $DISK"
fi
echo -e "  mem=$MEM  cpus=$CPUS  accel=${ACCEL[*]:-none}\n  firmware=$FW_CODE"
echo -e "  ${GREEN}ssh from host:${NC}  ssh -p $SSH_PORT root@localhost   (in the guest first: passwd root)"

exec qemu-system-x86_64 "${ARGS[@]}"
