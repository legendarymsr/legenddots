#!/usr/bin/env bash
# =============================================================================
# termux/guix-proot.sh — GNU Guix in a Termux proot (reusable, general-purpose).
#
# Termux can't run Guix natively (no root, no user namespaces, no /gnu/store), so
# this layers Guix on a proot-distro base (Debian by default) and runs the daemon
# with `--disable-chroot`, the way proot requires. It's the same Guix host that
# icecat.sh uses — set it up once here and `guix install` whatever you want.
#
#   bash ~/legenddots/termux/guix-proot.sh            # set up the proot + Guix
#   bash ~/legenddots/termux/guix-proot.sh guix ...   # run a guix command
#   bash ~/legenddots/termux/guix-proot.sh pull       # guix pull (update Guix)
#   bash ~/legenddots/termux/guix-proot.sh weather P  # is there a prebuilt binary?
#   bash ~/legenddots/termux/guix-proot.sh login      # interactive shell in it
#   bash ~/legenddots/termux/guix-proot.sh daemon     # just (re)start the daemon
#   bash ~/legenddots/termux/guix-proot.sh doctor     # check the setup end-to-end
#   bash ~/legenddots/termux/guix-proot.sh reset      # wipe the proot, start clean
#
# Env: GUIX_DISTRO  base proot distro (default: debian)
#
# HONEST CAVEATS (same as icecat.sh — see termux/README.md):
#   * Guix's daemon wants user namespaces / real root that proot only fakes, so
#     Guix-in-proot is FRAGILE; this runs the standard steps but can't guarantee
#     first-run success. If it wedges, finish by hand inside `… login`.
#   * aarch64 substitutes are patchy — packages without a prebuilt binary BUILD
#     FROM SOURCE (can be hours). `guix weather PKG` tells you before you commit.
# =============================================================================
set -u

DISTRO="${GUIX_DISTRO:-debian}"
say()  { echo ":: $*"; }
warn() { echo "!! $*" >&2; }

# Hold a CPU wakelock during long builds so Android doesn't suspend/kill Termux.
wake()   { command -v termux-wake-lock   >/dev/null 2>&1 && termux-wake-lock   2>/dev/null || true; }
unwake() { command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null || true; }

# The #1 cause of "guix pull crashes Termux": Android 12+ kills any app with lots
# of child processes (the "phantom process killer"), and proot + guix spawn many.
# This can only be disabled from a computer (or wireless adb) — print how, once.
phantom_note() {
  cat >&2 <<'EOF'
!! If Termux dies mid-build (not an error, just gone), it's Android's phantom-
!! process killer. Disable it over adb (survives reboot) — from a PC or wireless adb:
!!   adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"
!!   adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
!!   adb shell settings put global settings_enable_monitor_phantom_procs false
!! Then reboot. (Also run `termux-wake-lock` — this script does it for you.)
EOF
}

# proot's seccomp emulation trips a lot of Guix/daemon syscalls on Termux —
# disabling it is slower but MUCH more reliable. Set for every proot we spawn.
export PROOT_NO_SECCOMP=1

# Substitute (prebuilt-binary) servers, best aarch64 coverage first. Bordeaux
# builds far more aarch64 than ci.guix.gnu.org, so this is the difference between
# "downloads a binary" and "compiles IceCat for six hours". Authorized in setup.
SUBS="https://bordeaux.guix.gnu.org https://ci.guix.gnu.org"

# The daemon line, reused everywhere. For proot reliability:
#   --disable-chroot          proot can't give real chroot
#   --disable-deduplication   store dedup hardlinks misbehave on proot's VFS
#   --substitute-urls         both farms (Bordeaux first = best aarch64)
# Falls back to no build-users group if it isn't set up; then WAITS for the
# daemon socket instead of a blind sleep, so the first guix call doesn't race it.
GUIX_SOCK="/var/guix/daemon-socket/socket"
DAEMON_START="
  mkdir -p /dev/shm 2>/dev/null; chmod 1777 /dev/shm 2>/dev/null || true
  if command -v guix-daemon >/dev/null 2>&1 && ! pgrep -x guix-daemon >/dev/null 2>&1; then
    ( guix-daemon --disable-chroot --disable-deduplication --cores=0 --substitute-urls='$SUBS' --build-users-group=guixbuild \
        >/var/log/guix-daemon.log 2>&1 \
      || guix-daemon --disable-chroot --disable-deduplication --cores=0 --substitute-urls='$SUBS' \
        >/var/log/guix-daemon.log 2>&1 ) &
    for _ in \$(seq 1 30); do [ -S '$GUIX_SOCK' ] && break; sleep 1; done
  fi"

# PATH where guix lands (pre- and post-`guix pull`), a locale path so Guix stops
# spamming locale warnings, and the daemon ensure. Shared by every mode.
PROOT_PREP="
  export PATH=/root/.config/guix/current/bin:/var/guix/profiles/per-user/root/current-guix/bin:\$PATH
  export GUIX_LOCPATH=/root/.guix-profile/lib/locale
  # Disable Guile's JIT: under proot its generated code / executable mmaps crash
  # (SIGILL/SIGSEGV), which is what takes Termux down on heavy ops like guix pull.
  # Costs a little speed, buys stability. Applies to the daemon too (same env).
  export GUILE_JIT_THRESHOLD=-1
  . /root/.guix-profile/etc/profile 2>/dev/null || true
  $DAEMON_START
"

# run a command string inside the proot (daemon ensured, guix on PATH)
in_proot() { proot-distro login "$DISTRO" --shared-tmp -- bash -lc "$PROOT_PREP
$1"; }

# ── subcommands that assume setup is already done ────────────────────────────
case "${1:-setup}" in
  guix)   shift; wake; exec proot-distro login "$DISTRO" --shared-tmp -- bash -lc "$PROOT_PREP
exec guix $(printf '%q ' "$@")" ;;
  pull)
    # The crasher is the Guile JIT under proot (handled globally in PROOT_PREP),
    # not memory — so don't cripple parallelism. Optionally cap it on low-RAM
    # devices via GUIX_CORES / GUIX_MAX_JOBS.
    phantom_note; wake
    pargs=""
    [ -n "${GUIX_CORES:-}" ]    && pargs="$pargs --cores=${GUIX_CORES}"
    [ -n "${GUIX_MAX_JOBS:-}" ] && pargs="$pargs --max-jobs=${GUIX_MAX_JOBS}"
    say "guix pull (Guile JIT off for proot stability)…"
    in_proot "guix pull${pargs} && guix describe"
    rc=$?; unwake; exit $rc ;;
  weather) shift; wake; in_proot "guix weather $(printf '%q ' "$@")"; rc=$?; unwake; exit $rc ;;
  daemon) in_proot 'pgrep -x guix-daemon >/dev/null && echo "guix-daemon running" || echo "failed to start — see /var/log/guix-daemon.log"'; exit $? ;;
  login)  wake; exec proot-distro login "$DISTRO" --shared-tmp -- bash -lc "$PROOT_PREP
exec bash -i" ;;
  doctor)
    echo ":: proot-distro: $(command -v proot-distro || echo MISSING)"
    echo ":: daemon substitute-urls (configured): $SUBS"
    in_proot '
      echo ":: guix: $(command -v guix 2>/dev/null || echo MISSING)  $(guix --version 2>/dev/null | head -1)"
      pgrep -x guix-daemon >/dev/null && echo ":: daemon: running" || echo ":: daemon: NOT running — see /var/log/guix-daemon.log"
      echo ":: JIT off? GUILE_JIT_THRESHOLD=${GUILE_JIT_THRESHOLD:-unset} (want -1)"
      # The ACL stores raw public keys, not hostnames — count the keys instead.
      n=$(grep -o "public-key" /etc/guix/acl 2>/dev/null | wc -l | tr -d " ")
      echo ":: authorized substitute keys: ${n:-0}  (ci + Bordeaux = 2–3; if 0, run: guix-proot.sh authorize)"
    '
    echo ":: confirm a package has a prebuilt binary with:  guix-proot.sh weather PKG"
    exit $? ;;
  authorize)
    # (Re)authorize both substitute farms — so Guix downloads binaries instead of
    # compiling. Safe to run anytime; idempotent.
    in_proot '
      for key in ci.guix.gnu.org bordeaux.guix.gnu.org; do
        for d in /var/guix/profiles/per-user/root/current-guix/share/guix \
                 /root/.config/guix/current/share/guix /usr/share/guix; do
          if [ -f "$d/$key.pub" ]; then
            guix archive --authorize < "$d/$key.pub" 2>/dev/null && echo ":: authorized $key"
            break
          fi
        done
      done
      n=$(grep -o "public-key" /etc/guix/acl 2>/dev/null | wc -l | tr -d " ")
      echo ":: authorized substitute keys now: ${n:-0}"
    '
    exit $? ;;
  reset)
    warn "removing the '$DISTRO' proot for a clean start (deletes its Guix too)…"
    proot-distro remove "$DISTRO" 2>/dev/null || proot-distro reset "$DISTRO" 2>/dev/null || true
    echo ":: done — now re-run:  bash ~/legenddots/termux/guix-proot.sh"; exit 0 ;;
  setup|"") : ;;   # fall through to the setup below
  *) warn "usage: guix-proot.sh [setup|guix ...|pull|weather PKG|authorize|login|daemon|doctor|reset]"; exit 1 ;;
esac

# ── setup ─────────────────────────────────────────────────────────────────────
phantom_note; wake   # long build ahead — hold a wakelock, warn about the killer
say "Installing proot-distro..."
pkg install -y proot-distro || { warn "could not install proot-distro"; exit 1; }

say "Installing the '$DISTRO' proot (the Guix host)..."
proot-distro install "$DISTRO" 2>/dev/null || say "  ($DISTRO already installed)"

say "Installing GNU Guix inside the proot (the fragile step)..."
proot-distro login "$DISTRO" --shared-tmp -- bash -lc '
  set -e

  # CRITICAL: bake the proot-safe Guix env into every shell of this proot BEFORE
  # running the installer. The Guix binary installer itself runs `guix` (e.g.
  # `guix archive --authorize`), and Guile`s JIT SIGILLs under proot — which is
  # what crashed Termux the moment setup reached the installer. /etc/profile.d is
  # sourced by every `bash -l`, so the installer child procs, the daemon, and any
  # manual `proot-distro login` all inherit JIT-off + guix on PATH + a locale.
  cat > /etc/profile.d/zz-guix-proot.sh <<PROF
export GUILE_JIT_THRESHOLD=-1
export GUIX_LOCPATH=/root/.guix-profile/lib/locale
export PATH=/root/.config/guix/current/bin:/var/guix/profiles/per-user/root/current-guix/bin:\$PATH
PROF
  . /etc/profile.d/zz-guix-proot.sh

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  # Guix binary-installer dependencies.
  apt-get install -y wget xz-utils gpg guile-3.0-libs ca-certificates locales || true

  if ! command -v guix >/dev/null 2>&1 \
     && [ ! -x /var/guix/profiles/per-user/root/current-guix/bin/guix ]; then
    echo ":: fetching the official GNU Guix install script..."
    cd /root
    wget -q https://guix.gnu.org/install.sh -O guix-install.sh
    # Non-interactive; sets up /gnu/store, the guixbuild users, and guix-daemon.
    # GUILE_JIT_THRESHOLD is already exported, so the installer`s guix calls are safe.
    yes "" | bash guix-install.sh \
      || echo "!! Guix installer reported errors (common in proot) — finish by hand: guix-proot.sh login"
  else
    echo ":: Guix already present."
  fi
' || warn "proot/Guix base setup hit errors — see termux/README.md for the manual steps."

say "Authorizing substitute servers (Bordeaux = good aarch64 binaries) + locales..."
# Second pass uses PROOT_PREP, so the daemon is up with BOTH substitute farms and
# guix is on PATH. Authorizing both keys is what lets Guix actually USE those
# prebuilt binaries instead of compiling everything.
in_proot '
  for key in ci.guix.gnu.org bordeaux.guix.gnu.org; do
    for d in /var/guix/profiles/per-user/root/current-guix/share/guix \
             /root/.config/guix/current/share/guix /usr/share/guix; do
      if [ -f "$d/$key.pub" ]; then
        guix archive --authorize < "$d/$key.pub" 2>/dev/null && echo "   authorized $key"
        break
      fi
    done
  done
  guix --version 2>/dev/null || echo "!! guix not on PATH yet — see README"
' || warn "key/locale step hit errors — see termux/README.md."

# REQUIRED: the binary-tarball Guix is pinned to an OLD release commit the build
# farms no longer serve, so substitutes read 0.0% for everything and every install
# tries to build from source (which crashes proot). `guix pull` realigns to a
# recent commit Bordeaux has aarch64 binaries for. Skip only if you know why.
if [ "${SKIP_PULL:-0}" = 1 ]; then
  warn "SKIP_PULL=1 — skipping guix pull; substitutes will read ~0% until you pull."
else
  say "guix pull — REQUIRED so substitutes work (JIT-off; ~10–30 min, mostly download)…"
  in_proot "guix pull && guix describe" \
    || warn "guix pull failed — re-run it: bash ~/legenddots/termux/guix-proot.sh pull"
  # locales after pull (now substitutable) so UTF-8 works + warnings stop.
  in_proot "guix install glibc-locales 2>/dev/null && echo '   installed glibc-locales' || true"
fi

cat <<EOF

:: Guix proot ready (base: $DISTRO). Try:
     bash ~/legenddots/termux/guix-proot.sh pull             # update Guix
     bash ~/legenddots/termux/guix-proot.sh guix install hello
     bash ~/legenddots/termux/guix-proot.sh login            # a shell inside it

Installed packages land in the proot's /root/.guix-profile. icecat.sh uses this
same '$DISTRO' proot, so its Guix install is shared with this one.

If a step failed, that's the known proot/Guix friction (no real namespaces).
See the "Genuine IceCat via Guix" notes in termux/README.md — the manual daemon
and substitute steps apply here too. Check 'guix weather PKG' before big builds.
EOF

unwake   # release the wakelock; builds done
