#!/usr/bin/env sh
# =============================================================================
# KISS in-chroot setup — runs INSIDE the kiss-chroot from install.sh.
# Configures the system, sets up the kiss-community repos, then builds a
# kernel + bootloader so the box actually boots. POSIX sh (the KISS base
# ships busybox ash, not bash).
# =============================================================================
set -eu

CYAN='\033[0;36m'; YEL='\033[0;33m'; GRN='\033[0;32m'; NC='\033[0m'
header() { printf '\n%b── %s %b\n' "$CYAN" "$*" "$NC"; }

HOSTNAME_="${HOSTNAME_:-kiss}"
TIMEZONE="${TIMEZONE:-America/New_York}"
PRIV_ESC="${PRIV_ESC:-doas}"
REBUILD_WORLD="${REBUILD_WORLD:-false}"
# Build the XMonad desktop (Xorg + GHC/Haskell) for the regular user. On by
# default — a KISS box with a real, simple-to-config tiling WM. See below.
INSTALL_XMONAD="${INSTALL_XMONAD:-true}"
export KISS_PROMPT=0          # don't stop for "Continue?" confirmations
export CFLAGS="${CFLAGS:--O2 -pipe -march=native}"
export CXXFLAGS="$CFLAGS"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"

# ── Repos + KISS_PATH ─────────────────────────────────────────────────────────
header "kiss-community repositories"
mkdir -p /var/db/kiss
if [ ! -d /var/db/kiss/repo/.git ]; then
  git clone --depth 1 https://codeberg.org/kiss-community/repo /var/db/kiss/repo
fi
# Persist KISS_PATH for every future login shell.
cat > /etc/profile.d/kiss.sh <<'EOF'
export KISS_PATH="/var/db/kiss/repo/core:/var/db/kiss/repo/extra:/var/db/kiss/repo/wayland:/var/db/kiss/repo/xorg"
export CFLAGS="-O2 -pipe -march=native"
export CXXFLAGS="$CFLAGS"
EOF
. /etc/profile.d/kiss.sh
kiss update

# Optionally rebuild the whole base with your CFLAGS (the purist path; slow).
if [ "$REBUILD_WORLD" = "true" ]; then
  header "Rebuilding world (this takes a while)"
  kiss upgrade
fi

# ── System configuration ──────────────────────────────────────────────────────
header "System configuration"
printf '%s\n' "$HOSTNAME_" > /etc/hostname
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
cat > /etc/hosts <<EOF
127.0.0.1  localhost $HOSTNAME_
::1        localhost $HOSTNAME_
EOF

# ── Baseline packages: init, fs tools, firmware, bootloader, privesc ──────────
header "Building baseline packages (compiles from source)"
# baseinit gives KISS its init scripts; the rest make it bootable + usable.
for pkg in baseinit e2fsprogs dosfstools eudev linux-firmware grub efibootmgr "$PRIV_ESC"; do
  printf '%b>> %s%b\n' "$GRN" "$pkg" "$NC"
  kiss build "$pkg"
  kiss install "$pkg"
done

# ── Kernel ────────────────────────────────────────────────────────────────────
# WHY AN LTS KERNEL, AND WHY 6.18:
#   KISS ships NO kernel — you build your own — and this is a set-and-forget
#   install, so we pin a LONGTERM (LTS) series that gets security patches for
#   years, not a mainline kernel that goes EOL ~2 months after release.
#   As of 2026 both 6.12 and 6.18 are current LTS kernels, and — this is the key
#   point — they carry the SAME projected EOL (Dec 2028). So an older LTS buys
#   no extra longevity; we default to the NEWEST LTS, 6.18, for better hardware
#   support (this MacBook's i915 graphics, Broadcom wifi, etc.) at identical
#   support length. (6.12 was the earlier, over-cautious pick — set KSERIES=6.12
#   if you want it.) Swap the kernel.org URL for linux-libre for a fully-free
#   kernel (see the repo's libre/ notes).
# defconfig gives a generic bootable kernel; uncomment `make menuconfig` to tune.
KSERIES="${KSERIES:-6.18}"
# Resolve the newest point release of the series at build time (so it never goes
# stale); fall back to the series' initial release if the lookup can't run.
KVER="${KVER:-$(curl -fsSL https://www.kernel.org/releases.json 2>/dev/null \
  | grep -oE "\"${KSERIES}\.[0-9]+\"" | tr -d '"' | sort -V | tail -1)}"
KVER="${KVER:-$KSERIES}"
header "Building the Linux kernel (LTS ${KVER}, defconfig)"
kiss build bc perl 2>/dev/null || true; kiss install bc perl 2>/dev/null || true
cd /usr/src
if [ ! -d "linux-${KVER}" ]; then
  curl -fL# -O "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz"
  tar xf "linux-${KVER}.tar.xz"
fi
cd "linux-${KVER}"
make defconfig
# To customise: uncomment the next line and it will open interactively.
# make menuconfig
make
make INSTALL_MOD_STRIP=1 modules_install
make install    # installs vmlinuz + System.map into /boot
cd /

# ── Bootloader (UEFI, GRUB with --removable so Macs boot it) ──────────────────
header "Installing GRUB (UEFI)"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=KISS --removable
grub-mkconfig -o /boot/grub/grub.cfg

# ── Users & passwords ─────────────────────────────────────────────────────────
header "Set the root password"
passwd root
printf '%bCreate a regular user? enter a name (blank to skip):%b ' "$YEL" "$NC"
read -r USERNAME || USERNAME=""
if [ -n "$USERNAME" ]; then
  adduser "$USERNAME" || true
  printf 'set %s password:\n' "$USERNAME"; passwd "$USERNAME" || true
  # doas: let wheel run as root. (sudo users: edit /etc/sudoers instead.)
  if [ "$PRIV_ESC" = "doas" ]; then
    echo "permit persist :wheel" > /etc/doas.conf
    addgroup wheel 2>/dev/null || true
    adduser "$USERNAME" wheel 2>/dev/null || true
  fi
fi

# ── Desktop: Xorg + XMonad (optional) ─────────────────────────────────────────
# WHY XMONAD, NOT DWM:
#   KISS is about SIMPLE, not just small. dwm makes you edit config.h and
#   recompile the WM in C by hand for every change; XMonad keeps the same tiling
#   minimalism but its whole config is one Haskell file (~/.xmonad/xmonad.hs)
#   that it recompiles itself on Mod-q. The one honest cost: XMonad needs GHC
#   (Haskell) to build — the single heavy dependency here — but the running WM
#   stays tiny. KISS ships no ghc in core/extra, so we bootstrap the Haskell
#   toolchain with ghcup and build xmonad from Hackage with cabal.
#   The config itself is the repo's SHARED one — kiss/xmonad.hs is a symlink to
#   ../xmonad/xmonad.hs, so KISS and the Arch xmonad/ rice stay in lockstep.
if [ "$INSTALL_XMONAD" = "true" ] && [ -n "${USERNAME:-}" ]; then
  header "Desktop: Xorg + XMonad for ${USERNAME}"

  # 1) X server + the tools the SHARED config (../xmonad/xmonad.hs) spawns +
  #    the X11 dev headers cabal needs to build the Haskell X11 binding. From the
  #    KISS xorg/community repos (names vary by repo revision — the loop tolerates
  #    a miss and tells you to build it by hand).
  #    NOTE: alacritty is Rust; on a KISS box you may prefer to swap the terminal
  #    in ../xmonad/xmonad.hs for st and build st instead.
  for pkg in xorg-server xinit xsetroot xrdb \
             libx11 libxext libxft libxinerama libxrandr libxss \
             alacritty rofi picom dunst physlock ttf-dejavu; do
    if kiss build "$pkg" && kiss install "$pkg"; then
      printf '%b>> %s%b\n' "$GRN" "$pkg" "$NC"
    else
      printf '%b!! %s not found in KISS_PATH — build it by hand later%b\n' "$YEL" "$pkg" "$NC"
    fi
  done
  # physlock needs root so the Mod-Shift-l TTY lock works from a keybind.
  [ -x /usr/bin/physlock ] && chmod u+s /usr/bin/physlock 2>/dev/null || true

  # 2) Haskell toolchain via ghcup (self-contained, no root; lands in the user's
  #    home). This is the heavy step — GHC is a large download/build.
  header "Installing GHC + cabal via ghcup (the one heavy dep)"
  su - "$USERNAME" -s /bin/sh <<'GHCUP' || printf '%bghcup step failed — install GHC/cabal by hand, then `cabal install xmonad`%b\n' "$YEL" "$NC"
set -eu
export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
export BOOTSTRAP_HASKELL_MINIMAL=1
curl -fsSL https://get-ghcup.haskell.org | sh
. "$HOME/.ghcup/env"
ghcup install ghc    --set recommended
ghcup install cabal  --set recommended
GHCUP

  # 3) Build xmonad + xmonad-contrib from Hackage and install the xmonad binary
  #    onto the user's PATH (~/.cabal/bin). The --lib install gives the libraries
  #    XMonad needs to recompile ~/.xmonad/xmonad.hs on Mod-q.
  header "Building xmonad + xmonad-contrib (cabal)"
  su - "$USERNAME" -s /bin/sh <<'XM' || printf '%bcabal build failed — run `cabal install --lib xmonad xmonad-contrib && cabal install xmonad` yourself%b\n' "$YEL" "$NC"
set -eu
. "$HOME/.ghcup/env" 2>/dev/null || true
cabal update
cabal install --lib xmonad xmonad-contrib
cabal install xmonad
cabal install xmobar || true   # the bar the shared config spawns
mkdir -p "$HOME/.xmonad"
XM

  # 4) Drop in the config + a startx entry, owned by the user.
  if [ -f /root/xmonad.hs ]; then
    install -Dm644 /root/xmonad.hs "/home/$USERNAME/.xmonad/xmonad.hs"
  else
    printf '%bxmonad.hs not staged in /root — copy kiss/xmonad.hs to ~/.xmonad/ by hand%b\n' "$YEL" "$NC"
  fi
  cat > "/home/$USERNAME/.xinitrc" <<'EOF'
# Put ghcup/cabal binaries on PATH so `xmonad` is found, then launch it.
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"
export PATH="$HOME/.cabal/bin:$HOME/.local/bin:$PATH"
exec xmonad
EOF
  chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME/.xmonad" "/home/$USERNAME/.xinitrc" 2>/dev/null || true
  printf '%bXMonad ready — log in as %s and run `startx`.%b\n' "$GRN" "$USERNAME" "$NC"
  printf '  Mod(Super)+Return = alacritty · Mod+p = rofi · Mod+Space = layout · Mod+b = bar · Mod+S+l = lock · Mod+q = reload\n'
fi

header "chroot setup complete"
printf '%bExit the chroot, then: swapoff, umount -R the target, reboot.%b\n' "$GRN" "$NC"
