#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# =============================================================================
# libre/run-vm-guix.sh — the libre LFS builder, but bootstrapped from a
# *Guix System* builder VM instead of Debian. Libre building libre (Guix's
# kernel is Linux-libre; Guix is FSF-endorsed). Same result as run-vm.sh.
#
# Needs `guix` on the HOST (you run Guix on Gentoo already). It:
#   - builds a Guix System builder image from guix-builder.scm,
#   - attaches a fresh target disk (/dev/vdb) + shares this repo over 9p — or,
#     if your QEMU lacks 9p/virtfs, a read-only repo tarball disk + a
#     virtio-serial log (SHARE=auto|9p|copy, same as run-vm.sh),
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
# Tunables: VM_DIR TARGET_SIZE MEM CPUS BUILDER_SIZE FHS SHARE ACCEL ALLOW_TCG
#           (+ boot: FW_CODE/VARS)
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
DONE_TAG="LIBRE-BUILD-DONE"                 # copy mode: guest prints this line instead
REPO_TAR="$VM_DIR/repo.tar"                 # copy mode: repo snapshot, attached ro
SHARE="${SHARE:-auto}"                      # auto | 9p | copy (see run-vm.sh)
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
  if [[ "$ACCEL" != tcg && -e /dev/kvm && ! -w /dev/kvm ]] && ! getent group kvm 2>/dev/null | grep -qw "$USER_NAME"; then
    header "Adding $USER_NAME to the kvm group"
    doas usermod -aG kvm "$USER_NAME" || warn "couldn't add $USER_NAME to the kvm group — do it by hand"
  fi
}

# ── how the repo gets into the builder: 9p if QEMU has it, else a tar disk ────
qemu_has_9p() {
  qemu-system-x86_64 -device help 2>/dev/null | grep -q '"virtio-9p-pci"'
}
how_to_get_9p() {
  cat >&2 <<'EOT'
  To get 9p/virtfs in QEMU (optional — the copy transport works without it):
    Gentoo:  echo 'app-emulation/qemu virtfs xattr' | doas tee /etc/portage/package.use/qemu-virtfs
             doas emerge -1av app-emulation/qemu
    Others:  use a QEMU built with --enable-virtfs (needs libcap-ng + libattr at
             build time). Debian/Ubuntu qemu-system-x86, Fedora qemu-kvm and Arch
             qemu-base/qemu-full ship it; self-built or minimal builds often don't.
    Check:   qemu-system-x86_64 -device help | grep virtio-9p
EOT
}
pick_share() {
  case "$SHARE" in
    9p)   qemu_has_9p || { warn "SHARE=9p but this QEMU has no virtio-9p device"; how_to_get_9p; die "re-run with SHARE=copy (or SHARE=auto)"; } ;;
    copy) echo -e "  share: copy (repo tar disk + virtio-serial log)" >&2 ;;
    auto) if qemu_has_9p; then SHARE=9p
            echo -e "  share: 9p offered (+ tar-disk fallback if the guest kernel can't mount it)" >&2
          else SHARE=copy
            warn "this QEMU ($(command -v qemu-system-x86_64)) has no 9p/virtfs support ('virtio-9p-pci' missing)"
            echo -e "  ${CYAN}->${NC} using SHARE=copy: the repo goes in as a read-only tarball disk and the" >&2
            echo -e "     build log streams back over virtio-serial. Same build, same checkpoints —" >&2
            echo -e "     nothing to install." >&2
            echo -e "     Optional — 9p gives the Guix builder a live, read-only view of the repo:" >&2
            how_to_get_9p
          fi ;;
    *)    die "SHARE must be auto, 9p or copy (got: $SHARE)" ;;
  esac
}

# copy mode: snapshot the repo (working tree as-is, incl. uncommitted edits)
make_repo_tar() {
  local ex=()
  case "$VM_DIR/" in "$REPO"/*) ex=(--exclude="./${VM_DIR#"$REPO"/}") ;; esac
  tar -C "$REPO" "${ex[@]}" -cf "$REPO_TAR.tmp" . || die "failed to tar up $REPO"
  mv -f "$REPO_TAR.tmp" "$REPO_TAR"
  echo -e "  repo snapshot: $REPO_TAR ($(du -h "$REPO_TAR" | cut -f1))"
}

# ── accelerator: KVM if /dev/kvm is usable, else multi-threaded TCG ──────────
# ACCEL=auto (default) | kvm | tcg.  ACCEL=tcg never touches /dev/kvm (for
# hosts where KVM is present but broken); TCG uses -cpu max + MTTCG.
ACCEL="${ACCEL:-auto}"
kvm_usable() { [[ "$ACCEL" != tcg && -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; }
pick_accel() {   # sets the global ACCEL_ARGS array
  case "$ACCEL" in auto|kvm|tcg) ;; *) die "ACCEL must be auto, kvm or tcg (got: $ACCEL)" ;; esac
  if kvm_usable; then
    ACCEL_ARGS=(-enable-kvm -cpu host)
  else
    [[ "$ACCEL" == kvm ]] && die "ACCEL=kvm but /dev/kvm isn't usable"
    # shellcheck disable=SC2054  # the commas are QEMU option syntax
    ACCEL_ARGS=(-accel tcg,thread=multi -cpu max)
  fi
}

ensure_kvm_access() {
  [[ "$ACCEL" == tcg ]] && { warn "ACCEL=tcg: software emulation (TCG), /dev/kvm untouched — many times slower"; return 0; }
  kvm_usable && return 0
  if getent group kvm 2>/dev/null | grep -qw "$USER_NAME"; then
    if [[ -z "${RUNVM_SG:-}" ]] && command -v sg >/dev/null 2>&1; then
      warn "activating the kvm group for this session…"; export RUNVM_SG=1
      exec sg kvm -c "$(printf '%q ' "$0" "$@")"
    fi
    warn "in kvm group but this shell predates it — log out/in and re-run"; exit 0
  fi
  if [[ "${ALLOW_TCG:-0}" == 1 ]]; then
    warn "no usable /dev/kvm — ALLOW_TCG=1: building with TCG software emulation (many times slower)"
    return 0
  fi
  warn "no /dev/kvm — a software build would take weeks; fix kvm first (or ALLOW_TCG=1)"; exit 1
}

# ── build the Guix System builder image (once; kept for resume) ──────────────
# Guix writes its qcow2 with zstd compression ("compression type: zstd"), which
# a QEMU built without zstd can't open ("qcow2: unknown compression type: 2").
# So the builder is always rewritten as a plain, uncompressed qcow2 with
# qemu-img; if qemu-img can't read zstd either, Guix builds a raw image (same
# MBR-hybrid layout, root label Guix_image) and that gets converted instead.
# Read the qcow2 header ourselves: a qemu-img without zstd can't even 'info' it.
# (qcow2 v3: magic QFI\xfb, version @4, header_length @100, compression_type @104;
#  1 = zstd, 0 = zlib — same as `qemu-img info` "compression type: zstd")
image_is_zstd() {
  local b
  b=$(od -An -tu1 -N105 "$1" 2>/dev/null | tr -s ' \n' ' ') || return 1
  read -r -a b <<< "$b"
  (( ${#b[@]} >= 105 )) || return 1
  [[ "${b[0]} ${b[1]} ${b[2]} ${b[3]}" == "81 70 73 251" ]] || return 1   # "QFI\xfb"
  (( b[7] >= 3 )) || return 1                                              # version >= 3
  (( (b[100]<<24 | b[101]<<16 | b[102]<<8 | b[103]) > 104 )) || return 1  # has the field
  (( b[104] == 1 ))
}

write_builder() {   # write_builder <src> <raw|qcow2>: uncompressed qcow2 -> $BUILDER
  local tmp="$BUILDER.tmp"
  rm -f "$tmp"
  if qemu-img convert -f "$2" -O qcow2 "$1" "$tmp" && ! image_is_zstd "$tmp"; then
    mv -f "$tmp" "$BUILDER"; chmod u+w "$BUILDER"
  else
    rm -f "$tmp"; return 1
  fi
}

guix_image() {      # guix_image <image type>: prints the store path of the image
  local out
  out="$(guix system image -t "$1" --image-size="$BUILDER_SIZE" "$SELF_DIR/guix-builder.scm")" || return 1
  out="$(printf '%s\n' "$out" | tail -n1)"
  [[ -f "$out" ]] || return 1
  printf '%s\n' "$out"
}

build_guix_image() {
  if [[ -f "$BUILDER" ]]; then
    image_is_zstd "$BUILDER" || return 0   # keep it: phase-1 checkpoints live on it
    header "Existing builder image is zstd-compressed — rewriting it uncompressed"
    write_builder "$BUILDER" qcow2 && return 0
    warn "qemu-img can't read zstd qcow2 either — rebuilding the builder from a raw image"
    rm -f "$BUILDER"
  fi
  command -v guix >/dev/null 2>&1 || die "guix not found"
  header "Building the Guix System builder image (guix system image)…"
  local out
  out="$(guix_image qcow2)" \
    || die "guix system image failed — fix guix-builder.scm (module/package names), or use ./run-vm.sh"
  header "Writing it out as an uncompressed qcow2 -> $BUILDER"
  if ! write_builder "$out" qcow2; then
    warn "qemu-img can't read Guix's zstd-compressed qcow2 (QEMU built without zstd) — building a raw image instead"
    out="$(guix_image mbr-hybrid-raw)" || die "guix system image -t mbr-hybrid-raw failed"
    write_builder "$out" raw || die "qemu-img convert of $out failed"
    guix gc -D "$out" >/dev/null 2>&1 || true   # the raw image is a full-size store file
  fi
}

provision() {
  mkdir -p "$VM_DIR" "$WORK"
  build_guix_image
  [[ -f "$TARGET" ]] || { header "Creating target disk $TARGET ($TARGET_SIZE)"; qemu-img create -f qcow2 "$TARGET" "$TARGET_SIZE" >/dev/null; }
}

run_build() {
  local f
  for f in guest-build-guix.sh guest-bootstrap.sh; do
    [[ -f "$SELF_DIR/$f" ]] || die "missing libre/$f"
  done
  pick_share
  provision
  rm -f "$DONE"; : > "$LOG"
  pick_accel
  # The copy transport (repo tar as a read-only virtio disk — added LAST so the
  # target stays /dev/vdb — plus the log over virtio-serial into $LOG, append=on)
  # is ALWAYS attached; the 9p shares are added on top when QEMU has virtfs.
  # guest-bootstrap.sh tries 9p first and falls back to the tar disk, so a guest
  # kernel without 9p (e.g. Debian's genericcloud kernel) still works.
  # NB: plain if=virtio, not -device virtio-blk-pci: explicit -device disks get
  # PCI slots before if=virtio ones and would renumber vda/vdb.
  make_repo_tar
  local share=(-drive "file=$REPO_TAR,if=virtio,format=raw,readonly=on"
               -chardev "file,id=buildlog,path=$LOG,append=on"
               -device virtio-serial-pci
               -device "virtserialport,chardev=buildlog,name=libre.log")
  if [[ "$SHARE" == 9p ]]; then
    share+=(-virtfs "local,path=$REPO,mount_tag=repo,security_model=mapped-xattr,readonly=on"
            -virtfs "local,path=$WORK,mount_tag=work,security_model=mapped-xattr")
  fi
  header "Building the libre system from a GUIX SYSTEM builder — headless, ~30–44 h"
  echo -e "  target=$TARGET  mem=$MEM  cpus=$CPUS  FHS=$FHS  share=$SHARE  accel=${ACCEL_ARGS[*]}"
  echo -e "  ${GRN}watch:${NC}  ./run-vm-guix.sh watch   (or tail -f $LOG)"
  echo -e "  the VM powers off by itself when the build finishes.\n"
  qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" -m "$MEM" -smp "$CPUS" \
    -drive "file=$BUILDER,if=virtio" \
    -drive "file=$TARGET,if=virtio" \
    -netdev user,id=n0 -device virtio-net,netdev=n0 \
    -device virtio-balloon,free-page-reporting=on \
    "${share[@]}" \
    -display none -serial mon:stdio
  if [[ -f "$DONE" ]] || grep -qx "$DONE_TAG" "$LOG" 2>/dev/null; then
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
  pick_accel
  header "Booting the libre system (login: gnu / libre — X starts into ratpoison)"
  exec qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" -m "$MEM" -smp "$CPUS" \
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
