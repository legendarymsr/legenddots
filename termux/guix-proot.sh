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

# PATH inside the proot where guix lands (pre- and post-`guix pull`), plus the
# command that starts the daemon if it isn't already up. Shared by every mode.
PROOT_PREP='
  export PATH=/root/.config/guix/current/bin:/var/guix/profiles/per-user/root/current-guix/bin:$PATH
  . /root/.guix-profile/etc/profile 2>/dev/null || true
  if command -v guix-daemon >/dev/null 2>&1 && ! pgrep -x guix-daemon >/dev/null 2>&1; then
    ( guix-daemon --build-users-group=guixbuild --disable-chroot \
        >/var/log/guix-daemon.log 2>&1 || \
      guix-daemon --disable-chroot >/var/log/guix-daemon.log 2>&1 ) &
    sleep 3
  fi
'

# run a command string inside the proot (daemon ensured, guix on PATH)
in_proot() { proot-distro login "$DISTRO" --shared-tmp -- bash -lc "$PROOT_PREP
$1"; }

# ── subcommands that assume setup is already done ────────────────────────────
case "${1:-setup}" in
  guix)   shift; exec proot-distro login "$DISTRO" --shared-tmp -- bash -lc "$PROOT_PREP
exec guix $(printf '%q ' "$@")" ;;
  pull)   in_proot 'guix pull && guix describe'; exit $? ;;
  daemon) in_proot 'pgrep -x guix-daemon >/dev/null && echo "guix-daemon running" || echo "failed to start — see /var/log/guix-daemon.log"'; exit $? ;;
  login)  exec proot-distro login "$DISTRO" --shared-tmp -- bash -lc "$PROOT_PREP
exec bash -i" ;;
  setup|"") : ;;   # fall through to the setup below
  *) warn "usage: guix-proot.sh [setup|guix ...|pull|login|daemon]"; exit 1 ;;
esac

# ── setup ─────────────────────────────────────────────────────────────────────
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

  export PATH=/var/guix/profiles/per-user/root/current-guix/bin:$PATH
  # Start the daemon (proot has no init).
  if command -v guix-daemon >/dev/null 2>&1 && ! pgrep -x guix-daemon >/dev/null 2>&1; then
    ( guix-daemon --build-users-group=guixbuild --disable-chroot >/var/log/guix-daemon.log 2>&1 \
      || guix-daemon --disable-chroot >/var/log/guix-daemon.log 2>&1 ) &
    sleep 3
  fi
  command -v guix >/dev/null 2>&1 && guix --version || echo "!! guix not on PATH yet — see README"
' || warn "proot/Guix setup hit errors — see termux/README.md for the manual steps."

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
