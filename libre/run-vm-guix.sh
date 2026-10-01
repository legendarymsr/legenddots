#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# =============================================================================
# libre/run-vm-guix.sh — the libre LFS builder, but bootstrapped from a
# *Guix System* builder VM instead of Debian. Libre building libre (Guix's
# kernel is Linux-libre; Guix is FSF-endorsed). Same result as run-vm.sh.
#
# Needs `guix` on the HOST (you run Guix on Gentoo already). It:
#   - builds a Guix System builder image from guix-builder.scm,
#   - attaches a fresh target disk (/dev/vdb) + shares this repo over 9p,
#   - the builder's Shepherd service auto-runs libre/guest-build-guix.sh:
#     phase 1 (base) natively, phase 2 (desktop) in a chroot, then halts.
#
#   ./run-vm-guix.sh         build (or resume) the whole thing, headless
#   ./run-vm-guix.sh boot    boot the FINISHED libre system (UEFI + GUI)
#   ./run-vm-guix.sh watch   tail the live build log
#
# Separate from run-vm.sh (own $VM_DIR): don't mix Debian/Guix builders on one
# target — phase-1 checkpoints live on the builder, so pick one and stick with
# it. EXPERIMENTAL / untested here (no Guix in the sandbox); run-vm.sh (Debian)
# is the known-good fallback.
#
# Tunables: VM_DIR TARGET_SIZE MEM CPUS BUILDER_SIZE FHS  (+ boot: FW_CODE/VARS)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }
[[ ${EUID:-$(id -u)} -eq 0 ]] && die "run as your user, not root."

SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO="$(cd "$SELF_DIR/.." && pwd)"
USER_NAME="${USER_NAME:-legend}"

VM_DIR="${VM_DIR:-$HOME/libre-vm-guix}"
TARGET="$VM_DIR/libre.qcow2"
TARGET_SIZE="${TARGET_SIZE:-80G}"
BUILDER="$VM_DIR/builder-guix.qcow2"
BUILDER_SIZE="${BUILDER_SIZE:-24G}"
WORK="$VM_DIR/work"
LOG="$WORK/build.log"
DONE="$WORK/done"
MEM="${MEM:-4G}"                           # 4G + balloon fits an 8G host; MEM=8G builds IceCat
CPUS="${CPUS:-$(nproc)}"
export FHS="${FHS:-0}"                      # passed through to guest-build-guix.sh

# ── prereqs: guix (to build the image), qemu, kvm ────────────────────────────
ensure_prereqs() {
  command -v guix >/dev/null 2>&1 || die "need 'guix' on the host to build the Guix builder image (you run Guix on Gentoo — make sure guix is in PATH), or use the Debian builder: ./run-vm.sh"
  local need=()
  command -v qemu-system-x86_64 >/dev/null 2>&1 || need+=("app-emulation/qemu")
  command -v qemu-img          >/dev/null 2>&1 || need+=("app-emulation/qemu")
  if (( ${#need[@]} )); then
    command -v doas >/dev/null 2>&1 || die "install these, then re-run: ${need[*]}"
    header "Installing prerequisites: ${need[*]}"
    grep -q 'QEMU_SOFTMMU_TARGETS' /etc/portage/make.conf 2>/dev/null || \
      echo 'QEMU_SOFTMMU_TARGETS="x86_64"' | doas tee -a /etc/portage/make.conf >/dev/null
    doas emerge -avN "${need[@]}" || die "emerge failed — install ${need[*]} by hand"
  fi
  if ! getent group kvm 2>/dev/null | grep -qw "$USER_NAME"; then
    header "Adding $USER_NAME to the kvm group"; doas usermod -aG kvm "$USER_NAME"
  fi
}
ensure_kvm_access() {
  [[ -w /dev/kvm ]] && return 0
  if getent group kvm 2>/dev/null | grep -qw "$USER_NAME"; then
    if [[ -z "${RUNVM_SG:-}" ]] && command -v sg >/dev/null 2>&1; then
      warn "activating the kvm group for this session…"; export RUNVM_SG=1
      exec sg kvm -c "$(printf '%q ' "$0" "$@")"
    fi
    warn "in kvm group but this shell predates it — log out/in and re-run"; exit 0
  fi
  warn "no /dev/kvm — a software build would take weeks; fix kvm first"; exit 1
}

# ── build the Guix System builder image (once; kept for resume) ──────────────
build_guix_image() {
  [[ -f "$BUILDER" ]] && return 0        # keep it: phase-1 checkpoints live on it
  command -v guix >/dev/null 2>&1 || die "guix not found"
  header "Building the Guix System builder image (guix system image)…"
  local out
  out="$(guix system image -t qcow2 --image-size="$BUILDER_SIZE" "$SELF_DIR/guix-builder.scm")" \
    || die "guix system image failed — fix guix-builder.scm (module/package names), or use ./run-vm.sh"
  out="$(printf '%s\n' "$out" | tail -n1)"
  [[ -f "$out" ]] || die "couldn't locate the built image (got: $out)"
  header "Copying image out of the store -> $BUILDER"
  cp "$out" "$BUILDER"; chmod u+w "$BUILDER"
}

provision() {
  mkdir -p "$VM_DIR" "$WORK"
  build_guix_image
  [[ -f "$TARGET" ]] || { header "Creating target disk $TARGET ($TARGET_SIZE)"; qemu-img create -f qcow2 "$TARGET" "$TARGET_SIZE" >/dev/null; }
}

run_build() {
  [[ -f "$SELF_DIR/guest-build-guix.sh" ]] || die "missing libre/guest-build-guix.sh"
  provision
  rm -f "$DONE"; : > "$LOG"
  local accel=(-cpu qemu64); [[ -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)
  header "Building the libre system from a GUIX SYSTEM builder — headless, ~30–44 h"
  echo -e "  target=$TARGET  mem=$MEM  cpus=$CPUS  FHS=$FHS"
  echo -e "  ${GRN}watch:${NC}  ./run-vm-guix.sh watch   (or tail -f $LOG)"
  echo -e "  the VM powers off by itself when the build finishes.\n"
  qemu-system-x86_64 \
    "${accel[@]}" -m "$MEM" -smp "$CPUS" \
    -drive "file=$BUILDER,if=virtio" \
    -drive "file=$TARGET,if=virtio" \
    -netdev user,id=n0 -device virtio-net,netdev=n0 \
    -device virtio-balloon,free-page-reporting=on \
    -virtfs "local,path=$REPO,mount_tag=repo,security_model=mapped-xattr,readonly=on" \
    -virtfs "local,path=$WORK,mount_tag=work,security_model=mapped-xattr" \
    -display none -serial mon:stdio
  if [[ -f "$DONE" ]]; then
    touch "$VM_DIR/.built"
    header "Build complete ✓ (bootstrapped from Guix System)"
    echo -e "  boot it:  ${GRN}./run-vm-guix.sh boot${NC}"
  else
    warn "builder powered off without a done-marker — check the log, then re-run to resume:"
    echo  "  ./run-vm-guix.sh watch"
  fi
}

# ── boot the FINISHED libre system (UEFI + GUI) ──────────────────────────────
detect_fw() {
  [[ -n "${FW_CODE:-}" ]] && return 0
  local d c
  for d in /usr/share/edk2/ovmf /usr/share/edk2-ovmf /usr/share/OVMF /usr/share/qemu /usr/share/edk2; do
    for c in OVMF_CODE.fd OVMF_CODE.4m.fd OVMF_CODE_4M.fd; do [[ -f "$d/$c" ]] && { FW_CODE="$d/$c"; return 0; }; done
  done
  return 1
}
run_boot() {
  [[ -f "$TARGET" ]] || die "no built system yet — run ./run-vm-guix.sh first"
  command -v qemu-system-x86_64 >/dev/null 2>&1 || ensure_prereqs
  detect_fw || die "OVMF not found — emerge sys-firmware/edk2-bin or set FW_CODE=/path/OVMF_CODE.fd"
  local fw_vars="${FW_VARS:-${FW_CODE/OVMF_CODE/OVMF_VARS}}"
  [[ -f "$fw_vars" ]] || fw_vars="$(dirname "$FW_CODE")/OVMF_VARS.fd"
  [[ -f "$fw_vars" ]] || die "OVMF_VARS not found — set FW_VARS=/path/OVMF_VARS.fd"
  local nvram="$VM_DIR/OVMF_VARS.fd"; [[ -f "$nvram" ]] || cp "$fw_vars" "$nvram"
  local disp="${DISPLAY_TYPE:-}"; [[ -z "$disp" ]] && for d in gtk sdl; do qemu-system-x86_64 -display help 2>/dev/null | grep -qw "$d" && { disp="$d"; break; }; done
  local accel=(-cpu qemu64); [[ -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)
  header "Booting the libre system (login: gnu / libre — X starts into ratpoison)"
  exec qemu-system-x86_64 \
    "${accel[@]}" -m "$MEM" -smp "$CPUS" \
    -drive "if=pflash,format=raw,readonly=on,file=$FW_CODE" \
    -drive "if=pflash,format=raw,file=$nvram" \
    -drive "file=$TARGET,if=virtio" \
    -device virtio-gpu -display "${disp:-gtk},gl=on" \
    -netdev user,id=n0 -device virtio-net,netdev=n0 -device virtio-rng \
    -device virtio-balloon,free-page-reporting=on
}

case "${1:-}" in
  ""|build)
    if [[ -f "$VM_DIR/.built" && -z "${1:-}" ]]; then
      header "Already built"; echo -e "  boot it:  ${GRN}./run-vm-guix.sh boot${NC}   (or 'build' to force a rebuild/resume)"; exit 0
    fi
    ensure_prereqs; ensure_kvm_access "$@"; run_build ;;
  boot)   run_boot ;;
  watch)  exec tail -n +1 -f "$LOG" ;;
  *)      die "usage: ./run-vm-guix.sh [build|boot|watch]" ;;
esac
