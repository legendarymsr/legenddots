#!/usr/bin/env bash
# =============================================================================
# termux/guix-proot-x86.sh — GNU Guix in an EMULATED x86_64 proot on aarch64.
#
# Why: aarch64 Guix substitutes are patchy (no IceCat) and source builds crash
# proot. x86_64 is Guix's best-covered arch — IceCat et al. download as prebuilt
# binaries, nothing builds. Cost: QEMU emulation, so it's slow.
#
# HOW (the working way): instead of hand-rolling `proot -q qemu`, this uses
# proot-distro's built-in foreign-arch support — `DISTRO_ARCH=x86_64 proot-distro
# install/login`. proot-distro extracts the rootfs correctly AND wires qemu in
# (binding the emulator into the guest), which hand-rolled proot gets wrong.
#
#   bash ~/legenddots/termux/guix-proot-x86.sh            # install x86_64 Debian + Guix + pull
#   bash ~/legenddots/termux/guix-proot-x86.sh guix install icecat    # downloads!
#   bash ~/legenddots/termux/guix-proot-x86.sh weather icecat
#   bash ~/legenddots/termux/guix-proot-x86.sh run -- icecat          # GUI into pocketwl
#   bash ~/legenddots/termux/guix-proot-x86.sh login|pull|authorize|daemon|doctor|reset
#
# Env: GUIX_X86_ALIAS (default debian-x86)  SKIP_PULL=1
#      PROOT_DISTRO_X64_EMULATOR=QEMU|BLINK  (Blink is an alt x86_64 emulator —
#      try it if QEMU misbehaves)
# =============================================================================
set -u
unset LD_PRELOAD 2>/dev/null || true     # termux-exec's execve hook conflicts with proot

ALIAS="${GUIX_X86_ALIAS:-debian-x86}"
EMU="${PROOT_DISTRO_X64_EMULATOR:-QEMU}"
ROOTFS_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs/$ALIAS"
say()  { echo ":: $*"; }
warn() { echo "!! $*" >&2; }

export PROOT_NO_SECCOMP=1
wake()   { command -v termux-wake-lock   >/dev/null 2>&1 && termux-wake-lock   2>/dev/null || true; }
unwake() { command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null || true; }

SUBS="https://bordeaux.guix.gnu.org https://ci.guix.gnu.org"
GUIX_SOCK="/var/guix/daemon-socket/socket"
DAEMON_START="
  mkdir -p /dev/shm 2>/dev/null; chmod 1777 /dev/shm 2>/dev/null || true
  if command -v guix-daemon >/dev/null 2>&1 && ! pgrep -x guix-daemon >/dev/null 2>&1; then
    ( guix-daemon --disable-chroot --disable-deduplication --cores=0 --substitute-urls='$SUBS' --build-users-group=guixbuild \
        >/var/log/guix-daemon.log 2>&1 \
      || guix-daemon --disable-chroot --disable-deduplication --cores=0 --substitute-urls='$SUBS' \
        >/var/log/guix-daemon.log 2>&1 ) &
    for _ in \$(seq 1 60); do [ -S '$GUIX_SOCK' ] && break; sleep 1; done
  fi"
PROOT_PREP="
  export PATH=/root/.config/guix/current/bin:/var/guix/profiles/per-user/root/current-guix/bin:\$PATH
  export GUIX_LOCPATH=/root/.guix-profile/lib/locale
  export GUILE_JIT_THRESHOLD=-1
  . /root/.guix-profile/etc/profile 2>/dev/null || true
  $DAEMON_START
"

# low-level: run a command in the emulated x86_64 proot-distro
pdx() { DISTRO_ARCH=x86_64 PROOT_DISTRO_X64_EMULATOR="$EMU" proot-distro login "$ALIAS" --shared-tmp -- "$@"; }
# run a bash -lc command string with the Guix env prepped
pd()  { pdx bash -lc "$PROOT_PREP
$1"; }

# Check via a REAL file: /bin is an absolute symlink to /usr/bin in the rootfs,
# which resolves to the host's path and breaks `[ -x .../bin/bash ]`. /etc isn't
# symlinked.
installed() { [ -e "$ROOTFS_DIR/etc/os-release" ]; }

# ── subcommands ──────────────────────────────────────────────────────────────
case "${1:-setup}" in
  guix)    shift; installed || { warn "run setup first"; exit 1; }; wake; pdx bash -lc "$PROOT_PREP
exec guix $(printf '%q ' "$@")"; rc=$?; unwake; exit $rc ;;
  pull)    installed || { warn "run setup first"; exit 1; }; wake; say "guix pull (emulated — slow)…"; pd "guix pull && guix describe"; rc=$?; unwake; exit $rc ;;
  weather) shift; installed || { warn "run setup first"; exit 1; }; wake; pd "guix weather $(printf '%q ' "$@")"; rc=$?; unwake; exit $rc ;;
  authorize)
    installed || { warn "run setup first"; exit 1; }
    pd '
      for key in ci.guix.gnu.org bordeaux.guix.gnu.org; do
        for d in /var/guix/profiles/per-user/root/current-guix/share/guix /root/.config/guix/current/share/guix /usr/share/guix; do
          [ -f "$d/$key.pub" ] && { guix archive --authorize < "$d/$key.pub" 2>/dev/null && echo ":: authorized $key"; break; }
        done
      done'
    exit $? ;;
  daemon)  installed || { warn "run setup first"; exit 1; }; pd 'pgrep -x guix-daemon >/dev/null && echo "guix-daemon running" || echo "not running — see /var/log/guix-daemon.log"'; exit $? ;;
  login)   installed || { warn "run setup first"; exit 1; }; wake; pdx bash -lc "$PROOT_PREP
exec bash -i"; unwake; exit $? ;;
  run)     # run a GUI app in pocketwl: guix-proot-x86.sh run -- icecat
    shift; [ "${1:-}" = "--" ] && shift
    installed || { warn "run setup first"; exit 1; }
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-$PREFIX/tmp}}"
    WL="${WAYLAND_DISPLAY:-wayland-1}"
    [ -S "$XDG_RUNTIME_DIR/$WL" ] || { warn "no Wayland socket — start pocketwl (termux/start) and run this INSIDE it"; exit 1; }
    wake
    DISTRO_ARCH=x86_64 PROOT_DISTRO_X64_EMULATOR="$EMU" proot-distro login "$ALIAS" --shared-tmp \
      --bind "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR" -- \
      env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$WL" MOZ_ENABLE_WAYLAND=1 GDK_BACKEND=wayland \
        bash -lc "$PROOT_PREP
exec $(printf '%q ' "$@")"
    rc=$?; unwake; exit $rc ;;
  doctor)
    echo ":: qemu: $(command -v qemu-x86_64 || echo MISSING)   emulator=$EMU"
    echo ":: rootfs: $(installed && echo "$ROOTFS_DIR" || echo 'NOT installed')"
    echo ":: daemon substitute-urls (configured): $SUBS"
    installed && pd '
      echo ":: arch: $(uname -m)  (want x86_64)"
      echo ":: guix: $(command -v guix 2>/dev/null || echo MISSING)  $(guix --version 2>/dev/null | head -1)"
      pgrep -x guix-daemon >/dev/null && echo ":: daemon: running" || echo ":: daemon: NOT running"
      echo ":: JIT off? GUILE_JIT_THRESHOLD=${GUILE_JIT_THRESHOLD:-unset} (want -1)"
      n=$(grep -o "public-key" /etc/guix/acl 2>/dev/null | wc -l | tr -d " "); echo ":: authorized substitute keys: ${n:-0}"
    '
    exit 0 ;;
  reset)   warn "removing the '$ALIAS' proot…"; proot-distro remove "$ALIAS" 2>/dev/null || true; echo ":: done — re-run setup"; exit 0 ;;
  setup|"") : ;;
  *) warn "usage: guix-proot-x86.sh [setup|guix ...|pull|weather PKG|run -- CMD|authorize|login|daemon|doctor|reset]"; exit 1 ;;
esac

# ── setup ─────────────────────────────────────────────────────────────────────
wake
say "Installing Termux deps (proot-distro + qemu-user-x86-64)…"
pkg install -y proot-distro qemu-user-x86-64 >/dev/null 2>&1 \
  || pkg install -y proot-distro qemu-user-x86-64 \
  || { warn "could not install proot-distro / qemu-user-x86-64"; exit 1; }

if ! installed; then
  say "Installing x86_64 Debian via proot-distro (DISTRO_ARCH=x86_64, emulator=$EMU)…"
  DISTRO_ARCH=x86_64 PROOT_DISTRO_X64_EMULATOR="$EMU" \
    proot-distro install debian --override-alias "$ALIAS" \
    || { warn "proot-distro install failed — try PROOT_DISTRO_X64_EMULATOR=BLINK, or reset"; exit 1; }
fi

# sanity: can the emulated rootfs actually run a program?
if ! pdx bash -lc 'true' >/dev/null 2>&1; then
  warn "The x86_64 proot can't execute under $EMU. Try the other emulator:"
  warn "  PROOT_DISTRO_X64_EMULATOR=BLINK bash ~/legenddots/termux/guix-proot-x86.sh reset"
  warn "  PROOT_DISTRO_X64_EMULATOR=BLINK bash ~/legenddots/termux/guix-proot-x86.sh"
  exit 1
fi
say "x86_64 Debian runs under $EMU ✓"

say "Installing GNU Guix inside the x86_64 proot (emulated — be patient)…"
pdx bash -lc '
  set -e
  cat > /etc/profile.d/zz-guix-proot.sh <<PROF
export GUILE_JIT_THRESHOLD=-1
export GUIX_LOCPATH=/root/.guix-profile/lib/locale
export PATH=/root/.config/guix/current/bin:/var/guix/profiles/per-user/root/current-guix/bin:$PATH
PROF
  . /etc/profile.d/zz-guix-proot.sh
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y || true
  apt-get install -y wget xz-utils gpg ca-certificates locales || true
  if ! command -v guix >/dev/null 2>&1 && [ ! -x /var/guix/profiles/per-user/root/current-guix/bin/guix ]; then
    cd /root; wget -q https://guix.gnu.org/install.sh -O guix-install.sh
    yes "" | bash guix-install.sh || echo "!! installer errors (see README)"
  else echo ":: Guix already present."; fi
' || warn "x86_64 Guix base setup hit errors — see termux/README.md"

say "Authorizing substitute servers…"
pd '
  for key in ci.guix.gnu.org bordeaux.guix.gnu.org; do
    for d in /var/guix/profiles/per-user/root/current-guix/share/guix /root/.config/guix/current/share/guix /usr/share/guix; do
      [ -f "$d/$key.pub" ] && { guix archive --authorize < "$d/$key.pub" 2>/dev/null && echo "   authorized $key"; break; }
    done
  done'

if [ "${SKIP_PULL:-0}" = 1 ]; then
  warn "SKIP_PULL=1 — skipping guix pull; substitutes may read ~0% until you pull."
else
  say "guix pull (emulated — slow but mostly download)…"
  pd "guix pull && guix describe" || warn "guix pull failed — re-run: guix-proot-x86.sh pull"
fi

unwake
cat <<EOF

:: x86_64 Guix proot ready (emulated via proot-distro + $EMU). x86_64 has the best
   substitute coverage, so packages — IceCat included — download instead of build:
     bash ~/legenddots/termux/guix-proot-x86.sh weather icecat     # expect >0%
     bash ~/legenddots/termux/guix-proot-x86.sh guix install icecat
     # then, from a terminal INSIDE pocketwl (termux/start):
     bash ~/legenddots/termux/guix-proot-x86.sh run -- icecat
   Everything runs under emulation, so it's slow — fine for light use.
   If QEMU acts up, retry with PROOT_DISTRO_X64_EMULATOR=BLINK (after reset).
EOF
