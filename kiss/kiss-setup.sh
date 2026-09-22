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
# Build the bspwm desktop (Xorg + bspwm, all C) for the regular user. On by
# default — a KISS box with a small, config-file-driven tiling WM. See below.
INSTALL_BSPWM="${INSTALL_BSPWM:-true}"
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

# ── System services & tuning (network · time · audio · zram · keymap · ucode) ─
header "System services & tuning"

# Packages (tolerant — names vary by KISS repo revision).
for pkg in dhcpcd wpa_supplicant openntpd alsa-utils zsh kbd intel-ucode; do
  if kiss build "$pkg" && kiss install "$pkg"; then
    printf '%b>> %s%b\n' "$GRN" "$pkg" "$NC"
  else
    printf '%b!! %s not in KISS_PATH — skip / build by hand%b\n' "$YEL" "$pkg" "$NC"
  fi
done

# NOTE — MacBook Air wifi: the BCM4360 needs the proprietary 'wl' (broadcom-sta)
# out-of-tree driver, which KISS doesn't package. Ethernet / USB-tether works via
# dhcpcd below; for wifi, build broadcom-sta against your kernel by hand (see the
# repo's gentoo/ notes), load 'wl', then wpa_supplicant + dhcpcd handle it.

# A boot hook. Most minimal inits run /etc/rc.local; for busybox init we also
# wire it into /etc/inittab. If your init does neither, source it yourself.
cat > /etc/rc.local <<'RC'
#!/bin/sh
# legenddots — daemons & tuning at boot

# console keymap (change to match setxkbmap in bspwm/bspwmrc)
loadkeys us 2>/dev/null || true

# zram swap: half of RAM, zstd-compressed
if modprobe zram 2>/dev/null || [ -e /sys/class/zram-control ]; then
  z=$(cat /sys/class/zram-control/hot_add 2>/dev/null || echo 0)
  b=$(awk '/MemTotal/{print int($2*512)}' /proc/meminfo)   # bytes = KB*1024/2
  echo zstd > "/sys/block/zram${z}/comp_algorithm" 2>/dev/null || true
  echo "$b"  > "/sys/block/zram${z}/disksize"       2>/dev/null || true
  mkswap "/dev/zram${z}" >/dev/null 2>&1 && swapon -p 100 "/dev/zram${z}" 2>/dev/null || true
fi

# network: DHCP on wired (and wifi once wl + wpa_supplicant are set up)
command -v dhcpcd >/dev/null 2>&1 && dhcpcd -b 2>/dev/null || true

# time sync
command -v ntpd >/dev/null 2>&1 && ntpd -s 2>/dev/null &

# restore the ALSA mixer (unmute) if a saved state exists
command -v alsactl >/dev/null 2>&1 && alsactl restore 2>/dev/null || true
RC
chmod +x /etc/rc.local
if [ -f /etc/inittab ] && ! grep -q 'rc.local' /etc/inittab 2>/dev/null; then
  printf '::once:/etc/rc.local\n' >> /etc/inittab
fi

# CPU microcode: the firmware is now on disk (/lib/firmware). EARLY load needs an
# initramfs, which this defconfig-kernel setup doesn't build — add one (booster /
# dracut) for early application, otherwise the kernel applies it late.

# The legenddots C tools (fetch-c, legendstatus, legendpass, legendserve, …).
if [ -d /root/c ]; then
  header "Building the legenddots C tools"
  if ( cd /root/c && make && make install ); then
    printf '%b>> C tools installed to /usr/local/bin%b\n' "$GRN" "$NC"
  else
    printf '%b!! C tools build failed — run `make -C c install` by hand%b\n' "$YEL" "$NC"
  fi
fi

# zsh as the user's login shell + the repo's .zshrc.
if [ -n "${USERNAME:-}" ] && command -v zsh >/dev/null 2>&1; then
  ZSH_BIN=$(command -v zsh)
  sed -i "/^${USERNAME}:/ s|[^:]*\$|${ZSH_BIN}|" /etc/passwd 2>/dev/null || true
  if [ -f /root/zshrc ]; then
    install -Dm644 /root/zshrc "/home/$USERNAME/.zshrc"
    chown "$USERNAME":"$USERNAME" "/home/$USERNAME/.zshrc"
  fi
fi

# ── Desktop: Xorg + bspwm (optional) ──────────────────────────────────────────
# WHY BSPWM, NOT DWM:
#   KISS is about SIMPLE, not just small. dwm makes you edit config.h and
#   recompile the WM in C for every change; bspwm does nothing on its own — you
#   configure it with a shell script (~/.config/bspwm/bspwmrc) and bind keys with
#   sxhkd. No recompiles, and — unlike XMonad — NO GHC/Haskell toolchain, which
#   sits far better on musl. Everything here is plain C.
#   The config is the repo's shared bspwm/ rice; install.sh stages it into the
#   chroot (/root/wm) and we copy it into the user's ~/.config below.
if [ "$INSTALL_BSPWM" = "true" ] && [ -n "${USERNAME:-}" ]; then
  header "Desktop: Xorg + bspwm for ${USERNAME}"

  # X server + the tools the shared config uses, from the KISS xorg/community
  # repos (names vary by repo revision — the loop tolerates a miss and tells you
  # to build it by hand). The terminal is st, built from source below with your
  # suckless config.h — no Rust, no alacritty.
  for pkg in xorg-server xinit xsetroot \
             libx11 libxext libxft libxinerama libxrandr \
             bspwm sxhkd polybar picom rofi dunst physlock dillo \
             git pkgconf ttf-dejavu; do
    if kiss build "$pkg" && kiss install "$pkg"; then
      printf '%b>> %s%b\n' "$GRN" "$pkg" "$NC"
    else
      printf '%b!! %s not found in KISS_PATH — build it by hand later%b\n' "$YEL" "$pkg" "$NC"
    fi
  done
  # physlock needs root so the super+shift+x TTY lock works from a keybind.
  [ -x /usr/bin/physlock ] && chmod u+s /usr/bin/physlock 2>/dev/null || true

  # st is a compile-time-configured terminal, so build it from source with your
  # suckless config.h (staged at /root/wm/st-config.h). All C — no Rust.
  if [ -f /root/wm/st-config.h ] && command -v git >/dev/null 2>&1; then
    header "Building st with your suckless config.h"
    [ -d /root/src/st/.git ] || git clone https://git.suckless.org/st /root/src/st 2>/dev/null || true
    if [ -d /root/src/st ]; then
      ln -sfn /root/wm/st-config.h /root/src/st/config.h
      if ( cd /root/src/st && make clean >/dev/null 2>&1; make && make install ); then
        printf '%b>> st installed%b\n' "$GRN" "$NC"
      else
        printf '%b!! st build failed — build it by hand from suckless/st/config.h%b\n' "$YEL" "$NC"
      fi
    fi
  fi

  # Copy the staged bspwm config into ~/.config (the repo isn't on the installed
  # system to symlink to), owned by the user.
  if [ -d /root/wm ]; then
    install -Dm755 /root/wm/bspwmrc    "/home/$USERNAME/.config/bspwm/bspwmrc"
    install -Dm644 /root/wm/sxhkdrc    "/home/$USERNAME/.config/sxhkd/sxhkdrc"
    install -Dm644 /root/wm/config.ini "/home/$USERNAME/.config/polybar/config.ini"
    install -Dm755 /root/wm/launch.sh  "/home/$USERNAME/.config/polybar/launch.sh"
    chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME/.config"
  else
    printf '%bbspwm config not staged in /root/wm — copy bspwm/ into ~/.config by hand%b\n' "$YEL" "$NC"
  fi

  # Dillo config — copied (Dillo reads only ~/.dillo/).
  if [ -d /root/dillo ]; then
    mkdir -p "/home/$USERNAME/.dillo"
    cp /root/dillo/dillorc /root/dillo/cookiesrc "/home/$USERNAME/.dillo/" 2>/dev/null || true
    chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME/.dillo"
  fi

  printf 'exec bspwm\n' > "/home/$USERNAME/.xinitrc"
  chown "$USERNAME":"$USERNAME" "/home/$USERNAME/.xinitrc" 2>/dev/null || true

  printf '%bbspwm ready — log in as %s and run `startx`.%b\n' "$GRN" "$USERNAME" "$NC"
  printf '  super+Return = st · super+p = rofi · super+w = dillo · super+shift+x = lock · super+alt+q = quit\n'
fi

header "chroot setup complete"
printf '%bExit the chroot, then: swapoff, umount -R the target, reboot.%b\n' "$GRN" "$NC"
