#!/usr/bin/env bash
# =============================================================================
# legend's libre-LFS build-in-a-VM launcher. ONE command builds the whole
# GNU/Linux-libre system for you — no babysitting the two phases by hand.
#
# How it works (so you can trust it):
#   - Boots a tiny headless Debian *cloud* VM as a disposable "builder".
#   - Attaches your real target disk as a second virtio disk (/dev/vdb) and
#     hands this repo in as a read-only tarball disk (/dev/vdc), streaming the
#     build log back over virtio-serial. If your QEMU has 9p/virtfs it's also
#     offered as a live read-only share, but it's optional: Debian's
#     genericcloud guest kernel can't mount 9p anyway. No root needed.
#   - cloud-init auto-runs libre/guest-bootstrap.sh -> libre/guest-build.sh
#     inside the builder, which:
#       1. installs the LFS host build tools (gcc, bison, parted, …) via apt,
#       2. PHASE 1: `LFS_DISK=/dev/vdb libre/setup`  -> builds the libre base
#          onto the target disk (toolchain, temp tools, chroot base,
#          Linux-libre kernel, GNU Shepherd),
#       3. PHASE 2: chroots into the freshly built target and reruns
#          `libre/setup` -> builds the desktop (Xorg, ratpoison, Emacs, …).
#          BLFS is built in a chroot by design, so this is the normal path.
#   - Powers off when done. Then boot the finished system with:  ./run-vm.sh boot
#
# Everything is CHECKPOINTED (libre/setup's own state files) and RESUMABLE:
# re-run this script and it picks up where the build stopped. A fresh cloud-init
# instance-id each launch is what makes the build commands re-run on resume.
#
#   ./run-vm.sh          build (or resume) the whole thing, then it powers off
#   ./run-vm.sh build    same, explicit
#   ./run-vm.sh boot     boot the FINISHED libre system (UEFI + GUI) to use it
#   ./run-vm.sh watch    tail the live build log
#
# Tunables (env): VM_DIR TARGET_SIZE MEM CPUS JOBS CLOUD_IMG_URL SHARE ACCEL ALLOW_TCG
#                 (and for boot: FW_CODE FW_VARS DISPLAY_TYPE)
#   SHARE=auto  (default) offer 9p too if this QEMU has virtio-9p
#   SHARE=9p    require 9p in QEMU (errors out if it's missing)
#   SHARE=copy  never offer 9p: repo -> read-only tar disk, log -> virtio-serial
#               (the tar disk is ALWAYS attached as the fallback; the repo is
#               snapshotted at launch — re-run to pick up edits)
#   ACCEL=auto  (default) KVM if /dev/kvm is usable, else TCG; ACCEL=tcg forces
#               software emulation (-cpu max, MTTCG) and never touches /dev/kvm
#   ALLOW_TCG=1 build without KVM (software emulation, very slow) instead of exiting
#   JOBS=N      make -jN in the guest for both phases (default: libre/setup's
#               own default in phase 1, nproc in phase 2)
#
# NOTE: this orchestration is new and the full build is ~30–44 h; it has not
# been run end-to-end on this machine. If a step wedges, `./run-vm.sh watch`
# shows where, and you can always fall back to the manual two-phase flow in
# README.md. The libre/setup build itself is the same proven script either way.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }
warn()   { echo -e "${YEL}warn:${NC} $*" >&2; }
die()    { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] && die "run as your user, not root — it uses doas itself where needed and the boot GUI needs your X session."

SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # …/legenddots/libre
REPO="$(cd "$SELF_DIR/.." && pwd)"                            # …/legenddots
USER_NAME="${USER_NAME:-legend}"

VM_DIR="${VM_DIR:-$HOME/libre-vm}"
TARGET="$VM_DIR/libre.qcow2"               # the system we're building
TARGET_SIZE="${TARGET_SIZE:-80G}"          # LFS + LLVM/IceCat build trees are huge
BUILDER="$VM_DIR/builder.qcow2"            # disposable Debian overlay
SEED="$VM_DIR/seed.iso"                    # cloud-init NoCloud seed
WORK="$VM_DIR/work"                        # 9p-shared rw scratch (log + done marker)
LOG="$WORK/build.log"                      # build log (9p file, or virtio-serial sink)
DONE="$WORK/done"                          # marker the guest touches when finished
DONE_TAG="LIBRE-BUILD-DONE"                # copy mode: guest prints this line instead
REPO_TAR="$VM_DIR/repo.tar"                # copy mode: repo snapshot, attached ro
SHARE="${SHARE:-auto}"                     # auto | 9p | copy
JOBS="${JOBS:-}"
MEM="${MEM:-4G}"                           # 4G fits an 8G host; virtio-balloon
                                           # (free-page-reporting) hands idle RAM
                                           # back to the host. IceCat auto-skips
                                           # under ~7G — set MEM=8G to build it.
CPUS="${CPUS:-$(nproc)}"
CLOUD_IMG="$VM_DIR/debian-builder-base.qcow2"
CLOUD_IMG_URL="${CLOUD_IMG_URL:-https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2}"

dl() { command -v curl >/dev/null 2>&1 && curl -fL# -o "$1" "$2" || wget -O "$1" "$2"; }

# ── prerequisites: qemu, an ISO tool for the seed, kvm access ────────────────
ISO_TOOL=""
find_iso_tool() { for t in xorrisofs genisoimage mkisofs; do command -v "$t" >/dev/null 2>&1 && { ISO_TOOL="$t"; return 0; }; done; return 1; }

ensure_prereqs() {
  local need=()
  command -v qemu-system-x86_64 >/dev/null 2>&1 || need+=("app-emulation/qemu")
  command -v qemu-img          >/dev/null 2>&1 || need+=("app-emulation/qemu")
  find_iso_tool || need+=("app-cdr/cdrtools")     # provides mkisofs; cdrkit=genisoimage, libisoburn=xorriso
  if (( ${#need[@]} )); then
    command -v doas >/dev/null 2>&1 || die "install these, then re-run: ${need[*]}"
    header "Installing prerequisites: ${need[*]}"
    grep -q 'QEMU_SOFTMMU_TARGETS' /etc/portage/make.conf 2>/dev/null || \
      echo 'QEMU_SOFTMMU_TARGETS="x86_64"' | doas tee -a /etc/portage/make.conf >/dev/null
    doas emerge -avN "${need[@]}" || die "emerge failed — install ${need[*]} by hand"
    find_iso_tool || die "still no mkisofs/genisoimage/xorrisofs — install app-cdr/cdrtools (or cdrkit / libisoburn)"
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
            echo -e "     (9p wouldn't help here anyway: Debian's genericcloud guest kernel has no 9p.)" >&2
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
      warn "activating the kvm group for this session (no re-login)…"; export RUNVM_SG=1
      exec sg kvm -c "$(printf '%q ' "$0" "$@")"
    fi
    warn "you're in the kvm group but this shell predates it — log out/in and re-run"; exit 0
  fi
  if [[ "${ALLOW_TCG:-0}" == 1 ]]; then
    warn "no usable /dev/kvm — ALLOW_TCG=1: building with TCG software emulation (many times slower)"
    return 0
  fi
  warn "no /dev/kvm — building WITHOUT acceleration would take weeks; fix kvm first (or ALLOW_TCG=1 to do it anyway)"; exit 1
}

# ── cloud-init NoCloud seed: mount the shares, run guest-build.sh, power off ──
write_seed() {
  local cidir="$VM_DIR/cloud-init"; mkdir -p "$cidir"
  cat > "$cidir/meta-data" <<EOF
instance-id: libre-build-$(date +%s)
local-hostname: libre-builder
EOF
  # guest-bootstrap.sh mounts the 9p shares, or (no 9p) unpacks the repo tar
  # disk and logs over virtio-serial, then runs guest-build.sh. It's embedded
  # base64 so it exists in the guest before the repo does.
  [[ "$JOBS" =~ ^[0-9]*$ ]] || die "JOBS must be a number (got: $JOBS)"
  cat > "$cidir/user-data" <<EOF
#cloud-config
bootcmd:
  - [ sh, -c, "modprobe 9pnet_virtio 2>/dev/null || true" ]
write_files:
  - path: /usr/local/sbin/libre-bootstrap
    permissions: '0755'
    encoding: b64
    content: $(base64 -w0 < "$SELF_DIR/guest-bootstrap.sh")
runcmd:
  - [ sh, -c, "JOBS=$JOBS /usr/local/sbin/libre-bootstrap libre/guest-build.sh" ]
  - [ sh, -c, "sync; poweroff" ]
EOF
  "$ISO_TOOL" -output "$SEED" -volid cidata -joliet -rock \
    "$cidir/user-data" "$cidir/meta-data" >/dev/null 2>&1 \
    || die "failed to build the cloud-init seed with $ISO_TOOL"
}

# ── provision disks ───────────────────────────────────────────────────────────
provision() {
  mkdir -p "$VM_DIR"
  [[ -f "$CLOUD_IMG" ]] || { header "Fetching Debian cloud image (builder base)"; dl "$CLOUD_IMG" "$CLOUD_IMG_URL" || die "cloud image download failed"; }
  # KEEP the builder overlay across runs: phase 1's host-side checkpoints
  # (/var/log/lfs-host.state, lfs-parts.env) live on it, and losing them would
  # make libre/setup re-partition and WIPE the target on resume. Delete the whole
  # $VM_DIR by hand to start completely fresh.
  if [[ ! -f "$BUILDER" ]]; then
    header "Creating builder overlay (Debian)"
    qemu-img create -f qcow2 -F qcow2 -b "$CLOUD_IMG" "$BUILDER" >/dev/null
    qemu-img resize "$BUILDER" 16G >/dev/null        # room for apt + build tools
  fi
  [[ -f "$TARGET" ]] || { header "Creating target disk $TARGET ($TARGET_SIZE)"; qemu-img create -f qcow2 "$TARGET" "$TARGET_SIZE" >/dev/null; }
  mkdir -p "$WORK"
}

# ── run the headless builder until it powers off ─────────────────────────────
run_build() {
  local f
  for f in guest-build.sh guest-bootstrap.sh; do
    [[ -f "$SELF_DIR/$f" ]] || die "missing libre/$f next to this script"
  done
  pick_share
  write_seed
  provision
  rm -f "$DONE" "$LOG"; : > "$LOG"
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
  header "Building the libre system — headless, ~30–44 h, checkpointed"
  echo -e "  target=$TARGET  mem=$MEM  cpus=$CPUS  jobs=${JOBS:-default}  share=$SHARE  accel=${ACCEL_ARGS[*]}"
  echo -e "  ${GRN}watch the log:${NC}  ./run-vm.sh watch   (or: tail -f $LOG)"
  echo -e "  the VM powers off by itself when the build finishes.\n"
  # serial goes to the terminal; $LOG carries the detailed build log
  qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" -m "$MEM" -smp "$CPUS" \
    -drive "file=$BUILDER,if=virtio" \
    -drive "file=$TARGET,if=virtio" \
    -drive "file=$SEED,media=cdrom" \
    -netdev user,id=n0 -device virtio-net,netdev=n0 \
    -device virtio-balloon,free-page-reporting=on \
    "${share[@]}" \
    -display none -serial mon:stdio
  if [[ -f "$DONE" ]] || grep -qx "$DONE_TAG" "$LOG" 2>/dev/null; then
    touch "$VM_DIR/.built"
    header "Build complete ✓"
    echo -e "  boot your new GNU/Linux-libre system:  ${GRN}./run-vm.sh boot${NC}"
  else
    warn "builder powered off without a done-marker — check the log, then re-run to resume:"
    echo  "  ./run-vm.sh watch"
  fi
}

# ── boot the FINISHED libre system for real use (UEFI + GUI) ──────────────────
detect_fw() {
  [[ -n "${FW_CODE:-}" ]] && return 0
  local d c
  for d in /usr/share/edk2/ovmf /usr/share/edk2-ovmf /usr/share/OVMF /usr/share/qemu /usr/share/edk2; do
    for c in OVMF_CODE.fd OVMF_CODE.4m.fd OVMF_CODE_4M.fd; do [[ -f "$d/$c" ]] && { FW_CODE="$d/$c"; return 0; }; done
  done
  return 1
}
run_boot() {
  [[ -f "$TARGET" ]] || die "no built system yet — run ./run-vm.sh first"
  command -v qemu-system-x86_64 >/dev/null 2>&1 || ensure_prereqs
  detect_fw || die "OVMF firmware not found — emerge sys-firmware/edk2-bin, or set FW_CODE=/path/OVMF_CODE.fd"
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
      header "Already built"
      echo -e "  boot it:  ${GRN}./run-vm.sh boot${NC}   (or ./run-vm.sh build to force a rebuild/resume)"
      exit 0
    fi
    ensure_prereqs; ensure_kvm_access "$@"; run_build ;;
  boot)   run_boot ;;
  watch)  exec tail -n +1 -f "$LOG" ;;
  *)      die "usage: ./run-vm.sh [build|boot|watch]" ;;
esac
