#!/usr/bin/env bash
# =============================================================================
# termux/guix-proot-x86.sh — GNU Guix in an EMULATED x86_64 proot on aarch64.
#
# Why: aarch64 Guix substitutes are patchy (no IceCat, etc.) and source builds
# crash proot. x86_64 is Guix's best-covered arch — almost everything, IceCat
# included, downloads as a prebuilt binary, so nothing has to build. The cost is
# QEMU user-mode emulation: 2–10x slower, and a GUI app like IceCat is sluggish.
#
# proot does NOT emulate a CPU by itself — it runs native binaries. This uses
# `proot -q qemu-x86_64` (QEMU user-mode) to run an x86_64 rootfs on your arm64
# phone. Needs the `qemu-user-x86-64` Termux package (installed below).
#
#   bash ~/legenddots/termux/guix-proot-x86.sh            # set up + guix pull
#   bash ~/legenddots/termux/guix-proot-x86.sh guix install icecat   # downloads!
#   bash ~/legenddots/termux/guix-proot-x86.sh weather icecat        # check binary
#   bash ~/legenddots/termux/guix-proot-x86.sh run -- icecat         # run a GUI app
#   bash ~/legenddots/termux/guix-proot-x86.sh login|pull|authorize|daemon|doctor|reset
#
# Env: X86_DIR (default ~/guix-x86)  X86_ROOTFS_URL  SKIP_PULL=1
#
# EXPERIMENTAL / untested here. The aarch64 guix-proot.sh is the fast native path;
# this is the "I need a package with no aarch64 binary (e.g. IceCat)" escape hatch.
# =============================================================================
set -u

X86_DIR="${X86_DIR:-$HOME/guix-x86}"
ROOTFS="$X86_DIR/rootfs"
# Clean Debian amd64 rootfs (apt-based, not Ubuntu). linuxcontainers timestamps
# the dir daily; we resolve the newest at setup. Override with a direct tarball
# URL via X86_ROOTFS_URL if you want to pin one (or use a different distro).
X86_BASE="${X86_BASE:-https://images.linuxcontainers.org/images/debian/bookworm/amd64/default}"
X86_ROOTFS_URL="${X86_ROOTFS_URL:-}"
say()  { echo ":: $*"; }
warn() { echo "!! $*" >&2; }

export PROOT_NO_SECCOMP=1              # proot seccomp + qemu don't mix well
wake()   { command -v termux-wake-lock   >/dev/null 2>&1 && termux-wake-lock   2>/dev/null || true; }
unwake() { command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null || true; }

SUBS="https://bordeaux.guix.gnu.org https://ci.guix.gnu.org"
GUIX_SOCK="/var/guix/daemon-socket/socket"

# Same proot-safe env as the native script. JIT off matters even more here: a
# Guile JIT inside qemu-user is both broken and pointless.
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

QEMU=""
find_qemu() { QEMU="$(command -v qemu-x86_64 || echo "$PREFIX/bin/qemu-x86_64")"; [ -x "$QEMU" ]; }

# run a bash -lc command string inside the emulated x86_64 rootfs.
# --link2symlink MUST match the extraction flag, or the hardlink-converted files
# (incl. the ELF loader) can't be resolved and every binary "goes missing".
pr() {
  proot --link2symlink -q "$QEMU" -0 -r "$ROOTFS" -b /dev -b /proc -b /sys --kill-on-exit -w /root \
    /usr/bin/env -i HOME=/root TERM="${TERM:-xterm}" \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      /bin/bash -lc "$PROOT_PREP
$1"
}

ensure_termux_deps() {
  say "Installing Termux deps (proot + qemu-user-x86-64)…"
  pkg install -y proot qemu-user-x86-64 wget tar xz-utils >/dev/null 2>&1 \
    || pkg install -y proot qemu-user-x86-64 wget tar xz-utils \
    || { warn "could not install proot / qemu-user-x86-64"; return 1; }
  mkdir -p "$PREFIX/tmp"            # proot stores temp files here (fixes can't-chmod proot-tmp)
  find_qemu || { warn "qemu-x86_64 not found after install"; return 1; }
}

# ── subcommands (assume setup done) ──────────────────────────────────────────
case "${1:-setup}" in
  guix)    shift; find_qemu || { warn "run setup first"; exit 1; }; wake; pr "exec guix $(printf '%q ' "$@")"; rc=$?; unwake; exit $rc ;;
  pull)    find_qemu; wake; say "guix pull (emulated — slow; JIT off)…"; pr "guix pull && guix describe"; rc=$?; unwake; exit $rc ;;
  weather) shift; find_qemu; wake; pr "guix weather $(printf '%q ' "$@")"; rc=$?; unwake; exit $rc ;;
  authorize)
    find_qemu; pr '
      for key in ci.guix.gnu.org bordeaux.guix.gnu.org; do
        for d in /var/guix/profiles/per-user/root/current-guix/share/guix /root/.config/guix/current/share/guix /usr/share/guix; do
          [ -f "$d/$key.pub" ] && { guix archive --authorize < "$d/$key.pub" 2>/dev/null && echo ":: authorized $key"; break; }
        done
      done'
    exit $? ;;
  daemon)  find_qemu; pr 'pgrep -x guix-daemon >/dev/null && echo "guix-daemon running" || echo "not running — see /var/log/guix-daemon.log"'; exit $? ;;
  login)   find_qemu || { warn "run setup first"; exit 1; }; wake; pr "exec bash -i"; unwake; exit $? ;;
  run)     # run a GUI app in pocketwl: guix-proot-x86.sh run -- icecat
    shift; [ "${1:-}" = "--" ] && shift
    find_qemu || { warn "run setup first"; exit 1; }
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-$PREFIX/tmp}}"
    WL="${WAYLAND_DISPLAY:-wayland-1}"
    [ -S "$XDG_RUNTIME_DIR/$WL" ] || { warn "no Wayland socket — start pocketwl (termux/start) and run this INSIDE it"; exit 1; }
    wake
    # bind the Termux runtime dir (with the wayland socket) into the emulated rootfs
    proot --link2symlink -q "$QEMU" -0 -r "$ROOTFS" -b /dev -b /proc -b /sys \
      -b "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR" --kill-on-exit -w /root \
      /usr/bin/env -i HOME=/root TERM="${TERM:-xterm}" \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$WL" \
        MOZ_ENABLE_WAYLAND=1 GDK_BACKEND=wayland \
        /bin/bash -lc "$PROOT_PREP
exec $(printf '%q ' "$@")"
    rc=$?; unwake; exit $rc ;;
  doctor)
    echo ":: qemu: $(command -v qemu-x86_64 || echo MISSING)"
    echo ":: rootfs: $([ -x "$ROOTFS/bin/bash" ] && echo "$ROOTFS" || echo MISSING)"
    echo ":: daemon substitute-urls (configured): $SUBS"
    find_qemu && pr '
      echo ":: arch: $(uname -m)  (want x86_64)"
      echo ":: guix: $(command -v guix 2>/dev/null || echo MISSING)  $(guix --version 2>/dev/null | head -1)"
      pgrep -x guix-daemon >/dev/null && echo ":: daemon: running" || echo ":: daemon: NOT running"
      echo ":: JIT off? GUILE_JIT_THRESHOLD=${GUILE_JIT_THRESHOLD:-unset} (want -1)"
      n=$(grep -o "public-key" /etc/guix/acl 2>/dev/null | wc -l | tr -d " "); echo ":: authorized substitute keys: ${n:-0}"
    '
    echo ":: tip: guix-proot-x86.sh weather icecat   (x86_64 should be >0%)"
    exit 0 ;;
  reset)   warn "removing $ROOTFS …"; chmod -R u+w "$ROOTFS" 2>/dev/null; rm -rf "$ROOTFS"; echo ":: done — re-run setup"; exit 0 ;;
  setup|"") : ;;
  *) warn "usage: guix-proot-x86.sh [setup|guix ...|pull|weather PKG|run -- CMD|authorize|login|daemon|doctor|reset]"; exit 1 ;;
esac

# ── setup ─────────────────────────────────────────────────────────────────────
wake
ensure_termux_deps || exit 1

# Self-heal: an earlier failed/incomplete extraction can leave /bin/bash present
# but the rootfs unable to actually execute under qemu (missing loader, etc.).
# The guard below only re-extracts when /bin/bash is absent, so detect a dead
# rootfs here and wipe it for a clean rebuild.
if [ -x "$ROOTFS/bin/bash" ] && ! pr 'true' >/dev/null 2>&1; then
  warn "existing rootfs can't run under qemu (incomplete earlier extraction) — rebuilding it…"
  chmod -R u+w "$ROOTFS" 2>/dev/null || true; rm -rf "$ROOTFS"
fi

if [ ! -x "$ROOTFS/bin/bash" ]; then
  mkdir -p "$ROOTFS"
  URL="$X86_ROOTFS_URL"
  if [ -z "$URL" ]; then
    say "Resolving the latest Debian amd64 rootfs…"
    IDX="$(wget -qO- "$X86_BASE/" 2>/dev/null || curl -fsSL "$X86_BASE/" 2>/dev/null)"
    # grab the newest timestamped dir's href (keeps the server's URL-encoding)
    TS="$(printf '%s' "$IDX" | grep -oE 'href="[0-9]{8}_[^"]*/"' | sed 's/href="//; s/"$//' | sort | tail -1)"
    [ -n "$TS" ] && URL="$X86_BASE/${TS}rootfs.tar.xz"
  fi
  [ -n "$URL" ] || { warn "couldn't resolve a rootfs URL — set X86_ROOTFS_URL=<tarball>"; exit 1; }
  TB="$X86_DIR/rootfs.tar.xz"
  say "Downloading Debian amd64 rootfs: $URL"
  wget -O "$TB" "$URL" || { warn "rootfs download failed ($URL)"; exit 1; }
  say "Extracting rootfs…"
  # Decompress with xz EXPLICITLY and pipe into tar — don't trust tar's xz
  # auto-detect. proot --link2symlink converts hardlinks (Android FS can't do
  # them); the --warning/--delay flags are what proot-distro itself uses on these
  # linuxcontainers tarballs. Errors are shown; the REAL gate is /bin/sh existing.
  xz -dc "$TB" | proot --link2symlink tar -C "$ROOTFS" \
      --warning=no-unknown-keyword --delay-directory-restore -xf - \
    || { warn "proot+tar path failed, trying plain tar…"; \
         xz -dc "$TB" | tar -C "$ROOTFS" --no-same-owner -xf - || true; }
  if [ ! -x "$ROOTFS/bin/sh" ]; then
    warn "extraction produced no rootfs (no /bin/sh) — see errors above."
    warn "clean up and retry:  bash ~/legenddots/termux/guix-proot-x86.sh reset"
    exit 1
  fi
  rm -f "$TB"
  mkdir -p "$ROOTFS/etc" "$ROOTFS/tmp" "$ROOTFS/root"; chmod 1777 "$ROOTFS/tmp" 2>/dev/null || true
  rm -f "$ROOTFS/etc/resolv.conf"    # may be a dangling symlink in the image
  printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' > "$ROOTFS/etc/resolv.conf"
fi

# Sanity: can the rootfs actually execute under QEMU? Fail loudly here instead of
# cascading execve errors through the whole Guix install.
if ! pr 'true' >/dev/null 2>&1; then
  warn "The x86_64 rootfs can't execute under QEMU emulation (qemu/proot layer, not Guix)."
  warn "  qemu binary: ${QEMU:-<unset>}"
  warn "  Try a clean rebuild:  bash ~/legenddots/termux/guix-proot-x86.sh reset"
  warn "  and confirm qemu works: command -v qemu-x86_64"
  exit 1
fi
say "x86_64 rootfs executes under emulation ✓"

say "Installing GNU Guix inside the x86_64 rootfs (emulated — be patient)…"
pr '
  set -e
  # bake proot-safe Guix env (JIT off etc.) into every shell BEFORE the installer
  cat > /etc/profile.d/zz-guix-proot.sh <<PROF
export GUILE_JIT_THRESHOLD=-1
export GUIX_LOCPATH=/root/.guix-profile/lib/locale
export PATH=/root/.config/guix/current/bin:/var/guix/profiles/per-user/root/current-guix/bin:\$PATH
PROF
  . /etc/profile.d/zz-guix-proot.sh
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y || true
  apt-get install -y wget xz-utils gpg ca-certificates locales || true
  if ! command -v guix >/dev/null 2>&1 && [ ! -x /var/guix/profiles/per-user/root/current-guix/bin/guix ]; then
    cd /root; wget -q https://guix.gnu.org/install.sh -O guix-install.sh
    yes "" | bash guix-install.sh || echo "!! installer errors (see README)"
  else
    echo ":: Guix already present."
  fi
' || warn "x86_64 Guix base setup hit errors — see termux/README.md"

say "Authorizing substitute servers…"
pr '
  for key in ci.guix.gnu.org bordeaux.guix.gnu.org; do
    for d in /var/guix/profiles/per-user/root/current-guix/share/guix /root/.config/guix/current/share/guix /usr/share/guix; do
      [ -f "$d/$key.pub" ] && { guix archive --authorize < "$d/$key.pub" 2>/dev/null && echo "   authorized $key"; break; }
    done
  done'

if [ "${SKIP_PULL:-0}" = 1 ]; then
  warn "SKIP_PULL=1 — skipping guix pull; substitutes may read ~0% until you pull."
else
  say "guix pull (emulated — slow but mostly download; realigns to a commit with substitutes)…"
  pr "guix pull && guix describe" || warn "guix pull failed — re-run: guix-proot-x86.sh pull"
fi

unwake
cat <<EOF

:: x86_64 Guix proot ready (emulated). Because x86_64 is Guix's best-covered arch,
   packages — IceCat included — download as binaries instead of building:
     bash ~/legenddots/termux/guix-proot-x86.sh weather icecat     # expect >0%
     bash ~/legenddots/termux/guix-proot-x86.sh guix install icecat
     # then, from a terminal INSIDE pocketwl (termux/start):
     bash ~/legenddots/termux/guix-proot-x86.sh run -- icecat
   Everything runs under QEMU emulation, so it's slow — fine for light use.
EOF
