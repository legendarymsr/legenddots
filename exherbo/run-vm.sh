#!/usr/bin/env bash
# =============================================================================
# Run Exherbo (or anything) in a UEFI KVM virtual machine.
#
#   ./run-vm.sh              first run  -> INSTALL (auto-downloads the Gentoo
#                            minimal ISO if missing, boots it). Inside the VM:
#                                DISK=/dev/vda ./install.sh
#                            after that -> BOOTS the installed system.
#   ./run-vm.sh install      force install mode again (re-run the ISO).
#   ./run-vm.sh /path.iso    install using a specific ISO.
#
# First run also creates the disk image + a writable copy of the UEFI NVRAM.
# Override via env: VM_DIR DISK_SIZE MEM CPUS FW_CODE FW_VARS DISPLAY_TYPE
#                   ISO_DEFAULT ISO_URL
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

VM_DIR="${VM_DIR:-$HOME/exherbo-vm}"
DISK="$VM_DIR/exherbo.qcow2"
DISK_SIZE="${DISK_SIZE:-20G}"
MEM="${MEM:-4G}"
CPUS="${CPUS:-$(nproc)}"
ISO_DEFAULT="${ISO_DEFAULT:-$HOME/live.iso}"
# Gentoo minimal install ISO (UEFI-bootable). Dated autobuilds rotate off the
# mirror eventually — if this 404s, bump the date or pass your own ISO / ISO_URL.
ISO_URL="${ISO_URL:-https://distfiles.gentoo.org/releases/amd64/autobuilds/20260913T163055Z/install-amd64-minimal-20260913T163055Z.iso}"

command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 not found — emerge app-emulation/qemu"
command -v qemu-img          >/dev/null || die "qemu-img not found — emerge app-emulation/qemu"
mkdir -p "$VM_DIR"

# ── Decide mode: install vs boot ──────────────────────────────────────────────
ARG="${1:-}"
ISO=""
if [[ "$ARG" == "install" ]]; then
  MODE="install"; ISO="${2:-}"
elif [[ -n "$ARG" ]]; then
  MODE="install"; ISO="$ARG"
elif [[ -f "$DISK" ]]; then
  MODE="boot"
else
  MODE="install"           # no disk yet -> first-run install
fi

# ── Locate the OVMF UEFI firmware (from sys-firmware/edk2-bin) ─────────────────
FW_CODE="${FW_CODE:-}"; FW_VARS="${FW_VARS:-}"
if [[ -z "$FW_CODE" ]]; then
  for d in /usr/share/edk2/ovmf /usr/share/edk2-ovmf /usr/share/OVMF /usr/share/qemu /usr/share/edk2; do
    for c in OVMF_CODE.fd OVMF_CODE.4m.fd OVMF_CODE_4M.fd; do
      [[ -f "$d/$c" ]] && { FW_CODE="$d/$c"; break 2; }
    done
  done
fi
[[ -n "$FW_CODE" ]] || die "OVMF firmware not found — emerge sys-firmware/edk2-bin (or set FW_CODE=/path/OVMF_CODE.fd)"
if [[ -z "$FW_VARS" ]]; then
  FW_VARS="${FW_CODE/OVMF_CODE/OVMF_VARS}"
  [[ -f "$FW_VARS" ]] || FW_VARS="$(dirname "$FW_CODE")/OVMF_VARS.fd"
fi
[[ -f "$FW_VARS" ]] || die "OVMF_VARS not found next to $FW_CODE — set FW_VARS=/path/OVMF_VARS.fd"

# ── First-run setup: writable NVRAM + disk image ──────────────────────────────
NVRAM="$VM_DIR/OVMF_VARS.fd"
[[ -f "$NVRAM" ]] || { header "Copying UEFI NVRAM -> $NVRAM"; cp "$FW_VARS" "$NVRAM"; }
[[ -f "$DISK" ]]  || { header "Creating disk $DISK ($DISK_SIZE)"; qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"; }

# ── Install mode: make sure we have an ISO (download the default if missing) ──
if [[ "$MODE" == "install" ]]; then
  [[ -n "$ISO" ]] || ISO="$ISO_DEFAULT"
  if [[ ! -f "$ISO" ]]; then
    if [[ "$ISO" == "$ISO_DEFAULT" ]]; then
      command -v curl >/dev/null || die "curl not found — needed to fetch the ISO"
      header "No ISO at $ISO — downloading Gentoo minimal"
      curl -fL# -o "$ISO" "$ISO_URL" || { rm -f "$ISO"; die "ISO download failed ($ISO_URL) — grab one by hand and pass it"; }
    else
      die "ISO not found: $ISO"
    fi
  fi
fi

# ── KVM acceleration (falls back to slow emulation if no access) ──────────────
ACCEL=()
if [[ -w /dev/kvm ]]; then
  ACCEL=(-enable-kvm -cpu host)
else
  warn "no /dev/kvm access — run: doas usermod -aG kvm legend   (then re-login)."
  warn "running WITHOUT KVM — it'll be painfully slow."
  ACCEL=(-cpu qemu64)
fi

# ── Pick a display backend qemu was actually built with ──────────────────────
DISPLAY_TYPE="${DISPLAY_TYPE:-}"
if [[ -z "$DISPLAY_TYPE" ]]; then
  for d in gtk sdl; do
    qemu-system-x86_64 -display help 2>/dev/null | grep -qw "$d" && { DISPLAY_TYPE="$d"; break; }
  done
fi
if [[ -n "$DISPLAY_TYPE" ]]; then
  DISP=(-vga virtio -display "$DISPLAY_TYPE")
else
  warn "no gtk/sdl display in this qemu build — using VNC on localhost:5900 (connect a VNC viewer)."
  DISP=(-vga virtio -display none -vnc :0)
fi

# ── Assemble and run ──────────────────────────────────────────────────────────
ARGS=(
  "${ACCEL[@]}"
  -m "$MEM" -smp "$CPUS"
  -drive "if=pflash,format=raw,readonly=on,file=$FW_CODE"
  -drive "if=pflash,format=raw,file=$NVRAM"
  -drive "file=$DISK,if=virtio"
  -netdev user,id=n0 -device virtio-net,netdev=n0
  "${DISP[@]}"
)

if [[ "$MODE" == "install" ]]; then
  ARGS+=(-cdrom "$ISO" -boot menu=on)
  header "Install mode — booting $ISO"
  echo -e "  ${GREEN}Inside the VM, run:${NC}  DISK=/dev/vda ./install.sh   (virtio disk = /dev/vda)"
else
  header "Boot mode — starting the installed system on $DISK"
fi
echo -e "  mem=$MEM  cpus=$CPUS  accel=${ACCEL[*]:-none}\n  firmware=$FW_CODE"

exec qemu-system-x86_64 "${ARGS[@]}"
