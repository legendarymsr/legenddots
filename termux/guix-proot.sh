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
#   bash ~/legenddots/termux/guix-proot.sh login      # interactive shell in it
#   bash ~/legenddots/termux/guix-proot.sh daemon     # just (re)start the daemon
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

# The daemon line, reused everywhere: no chroot (proot), both substitute farms,
# all cores; fall back to no build-users if the group isn't set up.
DAEMON_START="
  if command -v guix-daemon >/dev/null 2>&1 && ! pgrep -x guix-daemon >/dev/null 2>&1; then
    ( guix-daemon --disable-chroot --cores=0 --substitute-urls='$SUBS' --build-users-group=guixbuild \
        >/var/log/guix-daemon.log 2>&1 \
      || guix-daemon --disable-chroot --cores=0 --substitute-urls='$SUBS' \
        >/var/log/guix-daemon.log 2>&1 ) &
    sleep 3
  fi"

# PATH where guix lands (pre- and post-`guix pull`), a locale path so Guix stops
# spamming locale warnings, and the daemon ensure. Shared by every mode.
PROOT_PREP="
  export PATH=/root/.config/guix/current/bin:/var/guix/profiles/per-user/root/current-guix/bin:\$PATH
  export GUIX_LOCPATH=/root/.guix-profile/lib/locale
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
    # guix pull is the big RAM spike that kills Termux. Run it with minimal
    # parallelism (override GUIX_CORES / GUIX_MAX_JOBS) + a wakelock, and remind
    # about the phantom-process killer, which is the usual real cause.
    phantom_note; wake
    say "guix pull with low parallelism (cores=${GUIX_CORES:-1}, jobs=${GUIX_MAX_JOBS:-1}) to cap RAM…"
    in_proot "guix pull --cores=${GUIX_CORES:-1} --max-jobs=${GUIX_MAX_JOBS:-1} && guix describe"
    rc=$?; unwake; exit $rc ;;
  daemon) in_proot 'pgrep -x guix-daemon >/dev/null && echo "guix-daemon running" || echo "failed to start — see /var/log/guix-daemon.log"'; exit $? ;;
  login)  wake; exec proot-distro login "$DISTRO" --shared-tmp -- bash -lc "$PROOT_PREP
exec bash -i" ;;
  setup|"") : ;;   # fall through to the setup below
  *) warn "usage: guix-proot.sh [setup|guix ...|pull|login|daemon]"; exit 1 ;;
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
  # UTF-8 locales (has substitutes, quick) so Guix stops warning + text renders.
  guix install glibc-locales 2>/dev/null && echo "   installed glibc-locales" || true
  guix --version 2>/dev/null || echo "!! guix not on PATH yet — see README"
' || warn "key/locale step hit errors — see termux/README.md."

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
