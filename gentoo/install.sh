#!/usr/bin/env bash
# =============================================================================
# Gentoo Install Script — MacBook Air 6,2 (THE FINAL PERFECTION)
# =============================================================================
set -euo pipefail

# ── Colours & Functions ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
header() { echo -e "\n\033[1m\033[36m── $* \033[0m"; }

# ── Configuration (10s prompts, defaults to WD-40 + doas if untouched) ───────
if [[ -z "${ENABLE_WD40:-}" ]]; then
  echo -e "${CYAN}Apply WD-40 (mask optional rust USE flag)? [Y/n] (10s, default: Y)${NC}"
  read -t 10 -r WD40_ANSWER || true; echo
  case "${WD40_ANSWER,,}" in
    n|no) ENABLE_WD40="false" ;;
    *)    ENABLE_WD40="true" ;;
  esac
fi

if [[ -z "${PRIV_ESC:-}" ]]; then
  echo -e "${CYAN}Privilege escalation tool? [doas/sudo] (10s, default: doas)${NC}"
  read -t 10 -r PRIV_ANSWER || true; echo
  case "${PRIV_ANSWER,,}" in
    sudo) PRIV_ESC="sudo" ;;
    *)    PRIV_ESC="doas" ;;
  esac
fi

# ── Pre-flight ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || exit 1
swapoff -a || true
umount -l /dev/sda* 2>/dev/null || true
wipefs -af /dev/sda

# ── Disk Setup ────────────────────────────────────────────────────────────────
header "Disk Management"
sgdisk --zap-all /dev/sda
sgdisk --new=1:0:+512M --typecode=1:ef00 /dev/sda
sgdisk --new=2:0:+8G   --typecode=2:8200 /dev/sda
sgdisk --new=3:0:0     --typecode=3:8304 /dev/sda
partprobe /dev/sda && udevadm settle

mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2 && swapon /dev/sda2
mkfs.ext4 -F /dev/sda3

mkdir -p /mnt/gentoo
mount /dev/sda3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount /dev/sda1 /mnt/gentoo/boot/efi

# ── Stage3 Unpack ─────────────────────────────────────────────────────────────
cd /mnt/gentoo
MIRROR="https://mirror.init7.net/gentoo"
STAGE3_PATH=$(curl -s "${MIRROR}/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt" \
    | grep -v '^#' | grep '\.tar\.xz' | awk '{print $1}' | head -1)
curl -# -O "${MIRROR}/releases/amd64/autobuilds/${STAGE3_PATH}"
tar xpf "$(basename "$STAGE3_PATH")" --xattrs-include='*.*' --numeric-owner
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# Persist the chosen options so resume.sh can re-enter the chroot after a
# crash without re-prompting (the chroot env wrapper below only reaches
# this first run).
{
  echo "ENABLE_WD40=${ENABLE_WD40}"
  echo "PRIV_ESC=${PRIV_ESC}"
} > /mnt/gentoo/etc/gentoo-install.env

# ── CHROOT LOGIC ──────────────────────────────────────────────────────────────
cat << 'CHROOT_EOF' > /mnt/gentoo/tmp/inside.sh
#!/bin/bash
set -euo pipefail
export DEBUGINFOD_URLS=""
export DEBUGINFOD_URLS_CERT_PATH=""
set +u; source /etc/profile; set -u
export PATH="/usr/sbin:/usr/local/sbin:/sbin:${PATH}"
TIMING_LOG=/var/log/gentoo-install-timing.log
mkdir -p "$(dirname "$TIMING_LOG")"
# Each header() call marks a new phase; logging the elapsed time since the
# previous call gives real per-phase durations for free, no per-step
# bookkeeping needed. Skipped (already-done) steps never call header(), so
# a resumed run's deltas only cover phases that actually ran this time.
header() {
  local now ts
  now=$(date +%s)
  ts=$(date '+%T')
  if [[ -n "${_PHASE_NAME:-}" ]]; then
    printf '[%s] %s -- finished after %dm%02ds\n' "$ts" "$_PHASE_NAME" \
      $(( (now - _PHASE_START) / 60 )) $(( (now - _PHASE_START) % 60 )) >> "$TIMING_LOG"
  fi
  _PHASE_NAME="$*"
  _PHASE_START="$now"
  printf '[%s] %s -- starting\n' "$ts" "$*" >> "$TIMING_LOG"
  echo -e "\n\033[1m\033[36m── $* \033[0m"
}

# resume.sh re-enters this same script after a crash; pick up the options
# chosen on the original run if they weren't passed in via the environment.
if [[ ( -z "${ENABLE_WD40:-}" || -z "${PRIV_ESC:-}" ) && -f /etc/gentoo-install.env ]]; then
  source /etc/gentoo-install.env
fi
ENABLE_WD40="${ENABLE_WD40:-true}"
PRIV_ESC="${PRIV_ESC:-doas}"

# ── Step checkpointing — lets resume.sh skip steps already completed ────────
STATE_FILE=/etc/gentoo-install.state
touch "$STATE_FILE"
step_done() { grep -qx "$1" "$STATE_FILE"; }
mark_step() { echo "$1" >> "$STATE_FILE"; }

# Allow overcommit so portage fork() calls don't fail with ENOMEM
# when the live-CD RAM is under pressure during heavy package builds
echo 1 > /proc/sys/vm/overcommit_memory
echo 262144 > /proc/sys/vm/max_map_count

# 1. PORTAGE SYNC & HARDENED PROFILE
if ! step_done portage_sync; then
  header "Syncing portage tree..."
  emerge-webrsync
  eselect profile set default/linux/amd64/23.0/hardened
  mark_step portage_sync
fi

# 2. KEYWORDS
# ACCEPT_KEYWORDS="~amd64" in make.conf already accepts all testing packages.
# Only need package.accept_keywords for the overlay wildcards so portage
# knows to trust packages from those repos.
mkdir -p /etc/portage/package.accept_keywords
{
  echo "*/*::guru ~amd64"
  echo "*/*::hyproverlay ~amd64"
  echo "*/*::another-brave-overlay ~amd64"
} > /etc/portage/package.accept_keywords/legend

# 3. MAKE.CONF
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=haswell -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j3"
# usepkg=y: reuse an already-built local binary package instead of
# recompiling if one matches (huge win on a resumed/repeated run).
# getbinpkg stays off -- Gentoo's official remote binhost only covers
# stock amd64/17.1 desktop profiles; for hardened it only ships the
# packages already in stage3, so it wouldn't help with anything we
# actually spend time compiling here (kernel, LLVM, clang, mesa, ...).
# autounmask-write/continue: when a dependency needs a USE flag this script
# didn't set explicitly (transitive deps shift between portage tree syncs),
# write the needed package.use change and keep going in the same invocation
# instead of halting and waiting on a manual `emerge --autounmask-write`
# rerun -- this script runs unattended, nothing's there to do that.
EMERGE_DEFAULT_OPTS="--jobs=1 --load-average=3 --quiet-build=y --usepkg=y --getbinpkg=n --backtrack=100 --autounmask-write=y --autounmask-continue=y"
CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
VIDEO_CARDS="intel iris"
ABI_X86="64"
LLVM_TARGETS="X86"
# -cuda/-rocm/-vdpau: Intel-only hardware, no Nvidia/AMD GPU stack needed
# -nls: skip building/installing translation catalogs (English-only system),
# shaves a little off nearly every package that has the flag
# -introspection: skips generating GObject introspection (.gir/.typelib) data
# for the glib/gtk-adjacent stack -- only needed by GIR consumers like
# gnome-shell extensions or python-gi scripting, neither of which this niri
# setup uses
# -gtk-doc/-doc: skip building each package's own HTML/API documentation
# -static-libs: skip building the .a alongside the .so most packages offer
# -- this is a CLI/desktop system, nothing here links anything statically
USE="udev elogind dbus wayland alsa -systemd -gnome -kde -qt5 -cups -pulseaudio -cuda -rocm -vdpau -nls -introspection -gtk-doc -doc -static-libs"
# Single python target instead of three -- packages using python-r1/
# distutils-r1 (a lot of them) build their python bindings once per
# PYTHON_TARGETS entry, so three targets means triple the python-related
# build work for versions this system never actually uses.
PYTHON_TARGETS="python3_13"
PYTHON_SINGLE_TARGET="python3_13"
# parallel-fetch: download the next package's sources while the current
# one compiles, instead of fetch-then-build-then-fetch serially.
# buildpkg: cache every built package as a binary in PKGDIR so a
# resumed/repeated emerge of the same package (e.g. after a crash, or the
# forced kernel/base_system re-runs resume.sh does for the broadcom-sta
# fix) can reuse it via usepkg instead of recompiling from source.
FEATURES="ccache parallel-fetch buildpkg"
CCACHE_DIR="/var/cache/ccache"
PKGDIR="/var/cache/binpkgs"
ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"
# Nearest mirrors to Sweden -- Lysator (Linköping, SE) first, dotsrc.org
# (Denmark) as fallback. Portage tries them left-to-right per file.
GENTOO_MIRRORS="https://ftp.lysator.liu.se/gentoo https://mirrors.dotsrc.org/gentoo"
EOF

mkdir -p /var/cache/ccache /var/cache/binpkgs
chown -R portage:portage /var/cache/ccache /var/cache/binpkgs

# FEATURES="ccache" above is a no-op until the ccache package itself is
# installed -- without it portage warns "no masquerade dir can be found
# in /usr/lib*/ccache/bin" and silently skips caching for every build.
# Must happen before the kernel/LLVM/clang builds to actually save anything.
if ! step_done ccache; then
  emerge dev-util/ccache
  # ccache defaults to a 5GiB max-size, which a single LLVM+clang+mesa+kernel
  # build cycle can blow through on its own -- once full, ccache starts
  # evicting old entries (LRU), so a resumed/repeated install gets far fewer
  # cache hits than it should. Compression keeps the larger cache from eating
  # disproportionate disk on a laptop SSD.
  CCACHE_DIR=/var/cache/ccache ccache --max-size=12G
  CCACHE_DIR=/var/cache/ccache ccache --set-config=compression=true
  chown -R portage:portage /var/cache/ccache
  mark_step ccache
fi

# mold -- a standalone C++ linker (no LLVM dependency, builds fine with gcc,
# so no chicken-and-egg problem using it to link LLVM/clang/mesa themselves).
# Dramatically faster and lighter on RAM than the default ld.bfd for linking
# huge binaries like clang and libLLVM.so -- linking is a serial, memory-
# heavy step MAKEOPTS/--jobs can't parallelize away, so this cuts real time
# without touching the parallelism/OOM tradeoff already settled at -j3.
if ! step_done mold; then
  # All of mold's own USE flags (debug, mimalloc, test) are already
  # default-off upstream and untouched by this profile -- pinned explicitly
  # anyway so it stays minimal even if a future profile update changes that.
  mkdir -p /etc/portage/package.use
  echo "sys-devel/mold -debug -mimalloc -test" > /etc/portage/package.use/mold
  emerge sys-devel/mold
  mark_step mold
fi

# O1 env override for slow packages — halves compile time with no practical
# runtime impact since these are build tools / shader compilers, not hot paths.
# LDFLAGS routes their link step through mold instead of the default ld.bfd.
mkdir -p /etc/portage/env /etc/portage/package.env
echo 'CFLAGS="-march=haswell -O1 -pipe"
CXXFLAGS="-march=haswell -O1 -pipe"
LDFLAGS="-fuse-ld=mold"' > /etc/portage/env/O1.conf

{
  echo "llvm-core/llvm O1.conf"
  echo "llvm-core/clang O1.conf"
  echo "media-libs/mesa O1.conf"
} > /etc/portage/package.env/O1

# package.use — set before any emerge so deps pick up the right flags
mkdir -p /etc/portage/package.use

# llvm-core/llvm and llvm-core/clang both default to USE="debug" upstream,
# which builds in assertions and extra debug codepaths -- this isn't a
# debug *build type*, it's always-on overhead in every compile this LLVM/
# clang ever does afterwards (e.g. mesa's shader compiler at runtime), on
# top of slowing down building LLVM/clang itself. clang also defaults to
# USE="extra" (clangd, clang-tidy, ...) and "static-analyzer" (scan-build),
# neither of which this system uses since gcc is the system compiler.
# -libffi drops llvm's (default-on) libffi interpreter-call binding --
# marginal build-time saving, but it's dead weight nothing here exercises.
{
  echo "llvm-core/llvm -debug -binutils-plugin -libffi"
  echo "llvm-core/clang -debug -extra -static-analyzer"
} > /etc/portage/package.use/llvm

# llvm-runtimes/clang-runtime defaults USE="+sanitize" on, which pulls in
# llvm-runtimes/compiler-rt-sanitizers -- a separate package that builds 15
# distinct instrumented runtime libraries (asan, tsan, msan, ubsan, lsan,
# dfsan, hwasan, libfuzzer, memprof, cfi, scudo, safestack, xray,
# ctx-profile, gwp-asan), one full compile pass each. Those are for
# instrumenting C/C++ programs being developed with -fsanitize=... flags,
# not something this system ever does. Nothing else depends on "sanitize"
# being on (REQUIRED_USE only goes the other way: sanitize needs
# compiler-rt, not vice versa), so this is a clean skip.
# The hardened profile also defaults USE="openmp" on globally, which here
# pulls in llvm-runtimes/openmp (clang's own OpenMP runtime, libomp) --
# unused, since gcc is the system compiler and has its own independent
# OpenMP support; nothing here ever invokes clang with -fopenmp.
echo "llvm-runtimes/clang-runtime -sanitize -openmp" > /etc/portage/package.use/llvm-runtimes

# PipeWire must expose a sound-server so wireplumber can act as its session manager
echo "media-video/pipewire sound-server" > /etc/portage/package.use/pipewire

# wireplumber needs elogind for seat/session management (we have no systemd)
echo "media-video/wireplumber elogind" > /etc/portage/package.use/wireplumber

# polkit must use elogind for privilege checks on a running seat
echo "sys-auth/polkit elogind" > /etc/portage/package.use/polkit

# NetworkManager: enable nmtui/nmcli tools
echo "net-misc/networkmanager tools" > /etc/portage/package.use/networkmanager


# elogind itself needs pam so login sessions are tracked properly
echo "sys-auth/elogind pam" > /etc/portage/package.use/elogind

# Waybar needs tray support and gtk-layer-shell for Wayland
echo "gui-apps/waybar tray" > /etc/portage/package.use/waybar

# Only build JetBrains Mono; building all ~3.5GB of nerd fonts is impractical
echo "media-fonts/nerdfonts jetbrainsmono" > /etc/portage/package.use/nerdfonts


# libglvnd X flag is off by default; mesa requires libglvnd[X] for GLX/XWayland
echo "media-libs/libglvnd X" > /etc/portage/package.use/libglvnd

# mesa defaults USE="llvm" on (gallium llvmpipe software rasterizer, AMD
# radeonsi, rusticl). VIDEO_CARDS is "intel iris" only -- the native Intel
# driver doesn't touch the LLVM gallium backend, so this is pure waste here,
# and it's one of the bigger individual mesa build-time costs.
echo "media-libs/mesa -llvm" > /etc/portage/package.use/mesa


# Desktop X11 libs needed by GTK/pango chain on Wayland
echo "x11-libs/cairo X" > /etc/portage/package.use/xlibs
echo "x11-libs/pango X" >> /etc/portage/package.use/xlibs
echo "x11-libs/libxkbcommon X" >> /etc/portage/package.use/xlibs
echo "dev-libs/libdbusmenu gtk3" >> /etc/portage/package.use/xlibs
# cairomm/atkmm wrap cairo and need the same X flag
echo "dev-cpp/cairomm X" >> /etc/portage/package.use/xlibs
echo "dev-cpp/atkmm X" >> /etc/portage/package.use/xlibs

# 4. OVERLAYS
if ! step_done overlays; then
  header "Setting up overlays..."
  emerge --oneshot app-eselect/eselect-repository dev-vcs/git
  eselect repository enable guru
  eselect repository add another-brave-overlay git \
      https://github.com/falbrechtskirchinger/another-brave-overlay.git || true
  eselect repository add hyproverlay git \
      https://codeberg.org/hyproverlay/hyproverlay.git || true
  emaint sync --repo guru                  || true
  emaint sync --repo another-brave-overlay || true
  emaint sync --repo hyproverlay           || true
  mark_step overlays
fi

# 5. WD-40 (de-rust the profile): masks the "rust" USE flag wherever a
#    package can be built without it. Can't eliminate rust entirely --
#    x11-terms/alacritty AND gui-wm/niri below are themselves written in
#    Rust and need dev-lang/rust regardless of this. Skip with
#    ENABLE_WD40=false.
if ! step_done wd40; then
  if [[ "$ENABLE_WD40" == "true" ]]; then
    header "Applying WD-40..."
    eselect repository create local || true
    echo "profile-formats = portage-2" >> /var/db/repos/local/metadata/layout.conf
    mkdir -p /var/db/repos/local/profiles/wd40-hardened
    echo "8" > /var/db/repos/local/profiles/wd40-hardened/eapi
    {
      echo "gentoo:default/linux/amd64/23.0/hardened"
      echo "gentoo:features/wd40"
    } > /var/db/repos/local/profiles/wd40-hardened/parent
    echo "amd64 wd40-hardened stable" > /var/db/repos/local/profiles/profiles.desc
    WD40_NUM=$(eselect profile list | sed -n 's/^[[:space:]]*\[\([0-9]\+\)\][[:space:]]\+local:wd40-hardened.*/\1/p')
    eselect profile set "${WD40_NUM}"

    # features/wd40/package.mask blanket-masks packages that hard-require rust
    # (no optional USE flag to strip) instead of leaving them buildable --
    # alacritty is one of them, but it's in the base package list regardless,
    # so unmask it specifically rather than disabling WD-40 wholesale.
    # gnome-base/librsvg is the same situation, one step removed: pavucontrol
    # pulls in GTK4 (gtkmm), and GTK4 hard-requires librsvg for SVG icon
    # rendering -- every librsvg version newer than 2.40 has been Rust-only
    # for years, and 2.40 itself was never keyworded for amd64, so there's no
    # rust-free version to fall back to here either.
    mkdir -p /etc/portage/package.unmask
    {
      echo "x11-terms/alacritty"
      echo "gnome-base/librsvg"
    } > /etc/portage/package.unmask/wd40-exceptions
    rm -f /etc/portage/package.unmask/alacritty

    # librsvg also defaults IUSE="+introspection +vala" on, and its own
    # REQUIRED_USE is "vala? ( introspection )" -- since the global USE trim
    # above already turns introspection off (unused without GNOME Shell/
    # python-gi), leaving vala on by itself violates that constraint. Nothing
    # here needs librsvg's Vala bindings either, so turn both off explicitly
    # to satisfy REQUIRED_USE instead of relying on the global flag alone.
    echo "gnome-base/librsvg -introspection -vala" > /etc/portage/package.use/librsvg
  else
    header "Skipping WD-40 (ENABLE_WD40=false)..."
  fi
  mark_step wd40
fi

# 6. KERNEL (gentoo-sources + manual hardening; hardened-sources was removed
#    from the Gentoo tree in 2024/2025)
if ! step_done kernel; then
  header "Building kernel..."

  # ACCEPT_KEYWORDS="~amd64" in make.conf is needed for the overlay packages,
  # but it also lets the kernel itself float on the bleeding-edge testing
  # series -- which net-wireless/broadcom-sta's unmaintained out-of-tree
  # source reliably fails to compile against (compat patches for it lag
  # behind by design). ACCEPT_KEYWORDS is an *incremental* portage variable
  # (like USE): just setting it to "amd64" here would only add to the
  # inherited "~amd64" from make.conf, not replace it -- "~amd64" already
  # implies "accept testing too", so that would be a no-op. The leading
  # "-~amd64" explicitly drops the inherited testing acceptance first, so
  # this one emerge call is genuinely restricted to the latest *stable*
  # release without touching the testing-wide default everything else uses.
  ACCEPT_KEYWORDS="-~amd64 amd64" emerge sys-kernel/gentoo-sources
  emerge sys-kernel/genkernel sys-kernel/linux-firmware sys-firmware/intel-microcode
  eselect kernel set 1
  cd /usr/src/linux
  make defconfig

  # --- INTEL ME REMOVAL ---
  ./scripts/config -d CONFIG_INTEL_MEI
  ./scripts/config -d CONFIG_INTEL_MEI_ME
  ./scripts/config -d CONFIG_INTEL_MEI_TXE
  ./scripts/config -d CONFIG_INTEL_MEI_HDCP
  ./scripts/config -d CONFIG_INTEL_MEI_PXP

  # --- MBA 6,2 HARDWARE ---
  ./scripts/config -e CONFIG_DRM_I915
  ./scripts/config -e CONFIG_SND_HDA_CODEC_CIRRUS
  ./scripts/config -e CONFIG_HID_APPLE
  ./scripts/config -e CONFIG_BT_HCIBTUSB
  ./scripts/config -e CONFIG_SATA_AHCI
  ./scripts/config -e CONFIG_X86_INTEL_PSTATE
  ./scripts/config -e CONFIG_THUNDERBOLT
  ./scripts/config -e CONFIG_USB_XHCI_HCD
  ./scripts/config -e CONFIG_USB_EHCI_HCD

  # --- BROADCOM-STA (wl) COMPATIBILITY ---
  # broadcom-sta refuses to build against CONFIG_PREEMPT_RCU (pulled in by
  # PREEMPT_DYNAMIC's default of "Preemptible Kernel") and against the
  # in-tree mac80211 stack it conflicts with -- not just the modprobe.d
  # blacklist (runtime) but the kernel build itself must drop these.
  ./scripts/config -d CONFIG_PREEMPT_DYNAMIC
  ./scripts/config -d CONFIG_PREEMPT
  ./scripts/config -e CONFIG_PREEMPT_NONE
  ./scripts/config -d CONFIG_BRCMSMAC
  ./scripts/config -d CONFIG_BRCMFMAC
  ./scripts/config -d CONFIG_BRCMUTIL
  ./scripts/config -d CONFIG_B43
  ./scripts/config -d CONFIG_B43LEGACY
  ./scripts/config -d CONFIG_SSB
  ./scripts/config -d CONFIG_MAC80211

  # --- HARDENED SECURITY ---
  ./scripts/config -e CONFIG_RANDOMIZE_BASE
  ./scripts/config -e CONFIG_RANDOMIZE_MEMORY
  ./scripts/config -e CONFIG_PAGE_TABLE_ISOLATION
  ./scripts/config -e CONFIG_MITIGATION_RETPOLINE
  ./scripts/config -e CONFIG_RETPOLINE
  ./scripts/config -e CONFIG_STRICT_KERNEL_RWX
  ./scripts/config -e CONFIG_STRICT_MODULE_RWX
  ./scripts/config -e CONFIG_SECURITY_LOCKDOWN_LSM
  ./scripts/config -e CONFIG_SECURITY_LOCKDOWN_LSM_EARLY
  ./scripts/config -d CONFIG_MODULE_SIG_FORCE

  # --- ZSWAP ---
  # Compressed RAM cache in front of the swap partition. Doesn't add RAM or
  # change how many parallel emerge jobs are safe -- it only makes it cheaper
  # when the box *does* swap under the LLVM/mesa/kernel build's memory
  # pressure, by compressing pages in RAM instead of writing them straight to
  # the (much slower) disk swap partition. lz4 over the zstd default: lower
  # CPU cost per page on this 4-thread box, where CPU is already the scarce
  # resource during builds -- zstd's better ratio isn't worth taking cycles
  # away from compiling.
  ./scripts/config -e CONFIG_ZSWAP
  ./scripts/config -e CONFIG_ZSMALLOC
  ./scripts/config -e CONFIG_CRYPTO_LZ4
  ./scripts/config -d CONFIG_ZSWAP_COMPRESSOR_DEFAULT_DEFLATE
  ./scripts/config -e CONFIG_ZSWAP_COMPRESSOR_DEFAULT_LZ4
  ./scripts/config -e CONFIG_ZSWAP_DEFAULT_ON

  make olddefconfig
  make -j3 && make modules_install && make install
  genkernel --no-clean --no-mrproper initramfs
  mark_step kernel
fi

# 7. BASE SYSTEM
if ! step_done base_system; then
  header "Emerging base system..."
  echo "mba" > /etc/hostname
  cat > /etc/hosts << 'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   mba.localdomain mba
EOF

  groupadd -f plugdev
  groupadd -f bluetooth

  PRIV_PKG="app-admin/doas"
  [[ "$PRIV_ESC" == "sudo" ]] && PRIV_PKG="app-admin/sudo"

  emerge \
    sys-apps/pciutils \
    sys-apps/usbutils \
    sys-process/procps \
    app-misc/figlet \
    x11-apps/igt-gpu-tools \
    sys-auth/elogind \
    net-misc/networkmanager \
    net-wireless/wpa_supplicant \
    net-wireless/broadcom-sta \
    net-wireless/bluez \
    "$PRIV_PKG" \
    sys-apps/dbus \
    sys-auth/polkit \
    sys-power/acpid \
    sys-power/tlp \
    sys-apps/lm-sensors \
    net-misc/wget \
    app-shells/zsh \
    dev-vcs/git \
    app-editors/neovim \
    media-video/pipewire \
    media-video/wireplumber \
    x11-terms/alacritty \
    llvm-core/llvm \
    llvm-core/clang \
    sys-boot/refind
  mark_step base_system
fi

# 8. DESKTOP (niri + full Wayland stack)
if ! step_done desktop; then
  # guru's media-fonts/nerdfonts-3.4.0 ebuild was refactored upstream
  # (2026-06-26, "DRY up ebuild by generating SRC_URI and IUSE") and the
  # refactor accidentally dropped S="${WORKDIR}". nerd-fonts release
  # tarballs extract flat (no wrapping directory matching ${P}), so
  # without that override the default S="${WORKDIR}/${P}" never exists
  # on disk and the build dies in the prepare phase before src_prepare
  # even runs. guru has thin-manifests=true (only DIST/tarball checksums
  # are tracked, not the ebuild text itself), so patching the synced copy
  # in place needs no Manifest regen.
  NERDFONTS_EBUILD="/var/db/repos/guru/media-fonts/nerdfonts/nerdfonts-3.4.0.ebuild"
  if [[ -f "$NERDFONTS_EBUILD" ]] && ! grep -q '^S="${WORKDIR}"' "$NERDFONTS_EBUILD"; then
    sed -i '/^FONT_SUFFIX=""$/a\
S="${WORKDIR}"' "$NERDFONTS_EBUILD"
  fi

  # dev-cpp/glibmm-2.88.1 (pulled in by dev-cpp/gtkmm, for pavucontrol's
  # GTK4 dependency) hardcodes -Dmaintainer-mode=true unconditionally (a
  # temporary upstream workaround, see the ebuild's own XXX comment) --
  # that runs gmmproc's binding codegen on every build, not just when the
  # gtk-doc USE flag is on, and gmmproc's DocsParser.pm unconditionally
  # `use`s Perl's XML::Parser module. The ebuild's BDEPEND only pulls
  # dev-lang/perl itself behind gtk-doc, missing this module entirely, so
  # the compile dies with "Can't locate XML/Parser.pm in @INC" regardless
  # of USE flags. Pre-emerge it so it's already present when glibmm builds.
  emerge --oneshot dev-perl/XML-Parser

  header "Emerging desktop..."
  emerge \
    gui-wm/niri \
    gui-apps/waybar \
    gui-apps/fuzzel \
    gui-apps/swaylock \
    gui-apps/swaybg \
    gui-apps/grim \
    gui-apps/slurp \
    gui-apps/wl-clipboard \
    x11-misc/dunst \
    gui-libs/xdg-desktop-portal-wlr \
    gnome-extra/polkit-gnome \
    media-sound/pavucontrol \
    x11-misc/xdg-utils \
    x11-misc/xdg-user-dirs \
    media-fonts/nerdfonts \
    www-client/brave-browser-nightly
  mark_step desktop
fi

# 9. LOCALIZATION & USER
if ! step_done localization_user; then
  header "Localizing and creating user..."
  echo "Europe/Stockholm" > /etc/timezone
  emerge --config sys-libs/timezone-data
  sed -i 's/keymap="us"/keymap="se"/' /etc/conf.d/keymaps
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
  echo "sv_SE.UTF-8 UTF-8" >> /etc/locale.gen
  locale-gen
  eselect locale set en_US.utf8
  env-update && set +u && source /etc/profile && set -u

  useradd -m -G wheel,audio,video,input,usb,plugdev,bluetooth -s /bin/zsh legend || true
  echo "legend:$(openssl passwd -6 'legendary')" | chpasswd -e
  echo "root:$(openssl passwd -6 'legendary123')" | chpasswd -e

  if [[ "$PRIV_ESC" == "sudo" ]]; then
    echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
    chmod 0440 /etc/sudoers.d/wheel
  else
    echo 'permit persist legend as root' > /etc/doas.conf
    chmod 0400 /etc/doas.conf
  fi

  # Dotfiles
  su - legend -c "git clone https://github.com/legendarymsr/legenddots ~/legenddots"
  su - legend -c "mkdir -p ~/Pictures/Screenshots"
  su - legend -c "
      mkdir -p ~/.config/alacritty ~/.config/niri
      ln -sfn ~/legenddots/alacritty.toml       ~/.config/alacritty/alacritty.toml
      ln -sfn ~/legenddots/.zshrc               ~/.zshrc
      ln -sfn ~/legenddots/niri/config.kdl      ~/.config/niri/config.kdl
      ln -sfn ~/legenddots/niri/waybar          ~/.config/waybar
      ln -sfn ~/legenddots/niri/fuzzel          ~/.config/fuzzel
      ln -sfn ~/legenddots/niri/dunst           ~/.config/dunst
      ln -sfn ~/legenddots/niri/swaylock        ~/.config/swaylock
  "

  xdg-user-dirs-update || true
  mark_step localization_user
fi

# 10. FINALIZE
if ! step_done finalize; then
  header "Finalizing..."

  # fstab
  ROOT_UUID=$(blkid -s UUID -o value /dev/sda3)
  EFI_UUID=$(blkid  -s UUID -o value /dev/sda1)
  SWAP_UUID=$(blkid -s UUID -o value /dev/sda2)
  {
      echo "UUID=${ROOT_UUID}  /          ext4  defaults,noatime  0 1"
      echo "UUID=${EFI_UUID}   /boot/efi  vfat  defaults,noatime  0 2"
      echo "UUID=${SWAP_UUID}  none       swap  sw                0 0"
  } > /etc/fstab

  # Broadcom wl
  cat > /etc/modprobe.d/broadcom-sta.conf << 'EOF'
blacklist brcmfmac
blacklist brcmsmac
blacklist b43
blacklist b43legacy
blacklist ssb
blacklist bcma
EOF
  echo 'modules="wl"' >> /etc/conf.d/modules

  # Apple keyboard fn-mode
  echo "options hid_apple fnmode=2" > /etc/modprobe.d/hid_apple.conf

  # Backlight permissions
  mkdir -p /etc/udev/rules.d
  cat > /etc/udev/rules.d/90-backlight.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF

  depmod -a "$(ls /lib/modules/ | grep gentoo | sort -V | tail -1)"

  # rEFInd — works natively with Apple EFI, auto-detects kernels, no config needed
  refind-install --usedefault /dev/sda1

  # rEFInd auto-detection finds vmlinuz but misses genkernel's
  # initramfs-genkernel-x86_64-* naming (the infix breaks its heuristics),
  # so without this file it boots the kernel bare and panics at root mount.
  KVER=$(basename "$(readlink -f /usr/src/linux)" | sed 's/^linux-//')
  INITRAMFS=$(ls /boot/initramfs-*"${KVER}"* 2>/dev/null | head -1 | sed 's|/boot/||')
  ROOT_UUID=$(blkid -s UUID -o value /dev/sda3)
  if [[ -n "$INITRAMFS" && -n "$ROOT_UUID" ]]; then
    printf '"Boot Gentoo"  "ro root=UUID=%s initrd=/boot/%s"\n' \
      "$ROOT_UUID" "$INITRAMFS" > /boot/refind_linux.conf
  fi

  # Services
  rc-update add NetworkManager default
  rc-update add bluetooth       default
  rc-update add dbus            default
  rc-update add elogind         default
  rc-update add acpid           default
  rc-update add tlp             default
  mark_step finalize
fi

header "Done. The Hardened Kingdom of Legend is built."
echo -e "\nPer-phase timings: $TIMING_LOG"
cat "$TIMING_LOG"
CHROOT_EOF

# ── Execution ─────────────────────────────────────────────────────────────────
chmod +x /mnt/gentoo/tmp/inside.sh
mount --types proc proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
chroot /mnt/gentoo /usr/bin/env ENABLE_WD40="$ENABLE_WD40" PRIV_ESC="$PRIV_ESC" /tmp/inside.sh
sync
echo -e "${GREEN}Reboot now: umount -R /mnt/gentoo && reboot${NC}"
