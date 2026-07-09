# LFS 12.4 + BLFS Desktop Setup — MacBook Air 6,2 / Niri + Wayland

One script, two phases. Phase 1 runs from a Gentoo host and builds a complete
Linux From Scratch 12.4 base system on a target disk. Phase 2 runs inside that
LFS system and builds the full Niri + Wayland desktop stack from source.

The script detects which phase to run automatically — the first invocation
(from the Gentoo host) builds the base system and exits with reboot instructions;
the second invocation (booted into LFS) builds the desktop.

---

## Prerequisites

### Phase 1 — Gentoo host requirements

| Tool | Used for |
|------|----------|
| gcc, g++ | cross-toolchain |
| make, bison, flex, gawk | build tools |
| grep, gzip, gperf, m4 | build tools |
| perl, python3 | build scripts |
| tar, xz, patch, diffutils | archive/patch |
| parted, mkfs.fat, mkswap, mkfs.ext4 | disk partitioning |
| wget | downloading sources |
| sys-boot/refind | bootloader (optional, can run later) |

### Phase 2 — LFS environment requirements

Everything needed for Phase 2 is already built during Phase 1 (wget, git, curl,
cmake, meson, ninja, zsh, doas, openssl). Nothing extra is required.

---

## Target Hardware

| Component | Detail |
|-----------|--------|
| CPU       | Intel Core i5-4250U (Haswell, 4T, up to 2.6 GHz) |
| iGPU      | Intel HD Graphics 5000 — Mesa `iris` + `crocus` drivers |
| WiFi      | Broadcom BCM4360 — proprietary `wl` module, built separately |
| Audio     | Cirrus Logic CS4208 (Intel HDA) — PipeWire handles it |
| Storage   | Apple PCIe SSD (AHCI) |
| RAM       | 8 GB |

Build flags set for this CPU:

```sh
CFLAGS="-march=haswell -O2 -pipe"
CXXFLAGS="-march=haswell -O2 -pipe"
MAKEFLAGS="-j3"
```

---

## Usage

### Phase 1 — from Gentoo host (as root)

```sh
git clone https://github.com/legendarymsr/legenddots ~/legenddots

# Optional: set the target disk in advance; the script will prompt if not set
export LFS_DISK=/dev/sdb

bash ~/legenddots/blfs/setup
```

The script partitions the disk, downloads ~80 source tarballs, builds the
cross-toolchain and temporary tools as the `lfs` user, then enters a chroot
to build the full LFS base system and kernel. When done, it installs rEFInd
and prints reboot instructions.

Completed steps are checkpointed to `/var/log/lfs-host.state`. If the build
is interrupted, rerun the same command to resume.

### Phase 2 — booted into LFS (as root)

```sh
git clone https://github.com/legendarymsr/legenddots ~/legenddots
bash ~/legenddots/blfs/setup
```

The script detects the `lfs_complete` marker written by Phase 1 and skips
straight to the BLFS desktop steps. Completed steps are checkpointed to
`/etc/blfs-setup.state`.

To reset a specific step and force it to rerun:

```sh
sed -i '/^mesa$/d' /etc/blfs-setup.state
bash ~/legenddots/blfs/setup   # reruns mesa only
```

---

## Build Order & Estimated Time

Times are wall-clock on a MacBook Air 6,2 (Haswell i5-4250U, `MAKEFLAGS=-j3`).
**Total across both phases: ~30–40 hours.** LLVM is the overwhelming bottleneck.

### Phase 1 — LFS base system (~8–12 hours)

| Step | What | Time |
|------|------|------|
| Disk | Partition + format | ~1 min |
| Sources | Download ~90 tarballs | ~20–60 min (network) |
| **Cross-toolchain** | | |
| | binutils pass 1 | ~5 min |
| | gcc pass 1 | ~12 min |
| | Linux API headers | ~1 min |
| | glibc 2.42 | ~20 min |
| | libstdc++ pass 1 | ~5 min |
| **Temporary tools** | (run as `lfs` user) | |
| | m4, ncurses, bash, coreutils, diffutils, file, findutils | ~10 min |
| | gawk, grep, gzip, make, patch, sed, tar, xz | ~5 min |
| | gettext (tools only) | ~5 min |
| | binutils pass 2, gcc pass 2 | ~20 min |
| **Chroot — base packages** | | |
| | glibc (final), zlib, bzip2, xz, zstd | ~25 min |
| | file, readline, m4, bc, flex, tcl | ~8 min |
| | binutils (final) | ~12 min |
| | mpfr, gmp, mpc, attr, acl, libcap, libxcrypt, shadow | ~8 min |
| | **gcc 15.2.0 (final)** | **~25 min** |
| | ncurses, sed, psmisc | ~5 min |
| | gettext, grep, bash, libtool, gdbm, gperf, expat | ~10 min |
| | inetutils, less, perl, XML-Parser, intltool | ~10 min |
| | autoconf, automake, openssl | ~8 min |
| | kmod, elfutils, libffi | ~5 min |
| | Python 3.13.7 | ~10 min |
| | flit_core, wheel, markupsafe, jinja2, packaging, setuptools | ~5 min |
| | ninja, meson | ~3 min |
| | coreutils, check, diffutils, gawk, findutils, groff | ~8 min |
| | gzip, iproute2, kbd, libpipeline, make, patch, tar | ~5 min |
| | vim | ~5 min |
| | eudev, man-db, procps, e2fsprogs | ~8 min |
| | sysklogd, sysvinit | ~2 min |
| | wget, curl, git, zsh, cmake, doas | ~15 min |
| | System config (fstab, inittab, locale, etc.) | ~1 min |
| **Kernel** | Linux 6.16.1, MacBook Air 6,2 config | ~30 min |
| **rEFInd** | Bootloader install | ~2 min |

### Phase 2 — BLFS desktop (~20–30 hours)

| Step | Package | Time |
|------|---------|------|
| 1 | D-Bus | ~3 min |
| 2 | PCRE2 | ~2 min |
| 3 | libffi | ~1 min |
| 4 | GLib | ~8 min |
| 5 | libpng | ~2 min |
| 6 | libjpeg-turbo | ~2 min |
| 7 | libtiff | ~3 min |
| 8 | libwebp | ~2 min |
| 9 | libdrm | ~2 min |
| 10 | Wayland | ~2 min |
| 11 | wayland-protocols | ~1 min |
| 12 | xkeyboard-config | ~1 min |
| 13 | libxkbcommon | ~3 min |
| 14 | pixman | ~3 min |
| 15 | FreeType (without HarfBuzz) | ~3 min |
| 16 | HarfBuzz | ~8 min |
| 17 | FreeType (with HarfBuzz) | ~3 min |
| 18 | fontconfig | ~3 min |
| 19 | Cairo | ~5 min |
| 20 | Pango | ~4 min |
| 21 | gdk-pixbuf | ~4 min |
| 22 | ATK | ~3 min |
| 23 | at-spi2-core | ~3 min |
| 24 | GTK+ 3 | ~20 min |
| 25 | Rust toolchain (rustup, pre-built) | ~5 min |
| 26 | librsvg | ~8 min |
| **27** | **LLVM 18** | **~6–10 h** |
| 28 | Mesa (iris + crocus + ANV Vulkan) | ~45 min |
| 29 | seatd | ~2 min |
| 30 | polkit | ~5 min |
| 31 | PipeWire | ~8 min |
| 32 | WirePlumber | ~5 min |
| 33 | niri (`cargo build --release`) | ~15 min |
| 34 | alacritty (`cargo build --release`) | ~10 min |
| 35 | waybar | ~8 min |
| 36 | fuzzel | ~3 min |
| 37 | swaylock | ~3 min |
| 38 | swaybg | ~2 min |
| 39 | dunst | ~3 min |
| 40 | grim | ~2 min |
| 41 | slurp | ~2 min |
| 42 | wl-clipboard | ~2 min |
| 43 | brightnessctl | ~1 min |
| 44 | fastfetch | ~3 min |
| 45 | Fonts | ~2 min |
| 46 | User setup + dotfile symlinks | ~1 min |
| 47 | MacBook Air 6,2 hardware config | ~1 min |

---

## What Gets Built

### Phase 1 — LFS base

A standard LFS 12.4 system: cross-toolchain targeting `x86_64-lfs-linux-gnu`,
~75 final packages (glibc, gcc, shadow, eudev, sysvinit, etc.), Linux 6.16.1
kernel tuned for MacBook Air 6,2 hardware. Extras added beyond the standard
LFS book: wget, curl, git, zsh, cmake, doas.

### Phase 2 — Desktop stack

**Graphics:** Mesa built with `iris` (primary for Haswell+), `crocus` (older
Intel gen), `swrast` (software fallback), and ANV Vulkan. GLX is disabled —
pure Wayland. LLVM is required for shader compilation and cannot be avoided.

**Compositor:** niri built via `cargo build --release`. Configured with Swedish
keyboard layout, JetBrains Nerd Font, Tokyo Night colours.

**Audio:** PipeWire + WirePlumber. Built without systemd or elogind. Session
tracking disabled at build time; seatd handles device access directly.

**Seat management:** seatd runs as a SysVinit init script, managing
`/dev/input/*` and `/dev/drm/*` for unprivileged Wayland sessions. `legend`
is added to the `seat` group.

**Rust toolchain:** Installed via rustup to `/usr/share/rustup` and
`/usr/share/cargo`. Both niri and alacritty compile against this toolchain.

---

## WiFi — BCM4360

The Broadcom BCM4360 has no in-tree mainline driver. The proprietary `wl`
module must be compiled against the running kernel headers after booting LFS:

```sh
wget https://www.lwfinger.com/downloads/hybrid-v35_64-nodebug-pcoem-6_30_223_271.tar.gz
tar -xf hybrid-v35_64-nodebug-pcoem-6_30_223_271.tar.gz
cd hybrid-v35_64-nodebug-pcoem-6_30_223_271

make -C /lib/modules/$(uname -r)/build M=$(pwd) modules
install -m 644 wl.ko /lib/modules/$(uname -r)/updates/
depmod -a
modprobe wl
```

For the install itself, tether your phone via USB — the `cdc_ether` or
`rndis_host` module handles USB tethering with no proprietary firmware.

---

## User & Dotfiles

Step 46 creates user `legend` and symlinks the full legenddots config:

| Symlink | Target |
|---------|--------|
| `~/.config/alacritty/alacritty.toml` | `~/legenddots/alacritty.toml` |
| `~/.zshrc` | `~/legenddots/.zshrc` |
| `~/.config/niri/config.kdl` | `~/legenddots/niri/config.kdl` |
| `~/.config/waybar/` | `~/legenddots/niri/waybar/` |
| `~/.config/fuzzel/` | `~/legenddots/niri/fuzzel/` |
| `~/.config/dunst/` | `~/legenddots/niri/dunst/` |
| `~/.config/swaylock/` | `~/legenddots/niri/swaylock/` |
| `~/.config/fastfetch/config.jsonc` | `~/legenddots/fastfetch/config.jsonc` |

### Default credentials

| Account | Password |
|---------|----------|
| legend | `legendary` |
| root | `legendary123` |

**Change these immediately after first boot:**

```sh
passwd legend
passwd root
```

---

## Privilege escalation

doas is built in Phase 1 and configured in Phase 2:

```
permit persist legend as root
```

`/etc/doas.conf` is set `chmod 0400`.

---

## Differences from the Gentoo setup

| | Gentoo | LFS + BLFS |
|--|--------|------------|
| Package manager | Portage (`emerge`) | None — tarballs + build scripts |
| Binary cache | `FEATURES=buildpkg` | None |
| Resume support | state file | state file (two: host + LFS) |
| LLVM build time | ~1.5 h (ccache, O1) | ~6–10 h (cold, O2) |
| Kernel | Managed by portage | Built by this script |
| Updates | `emerge --update @world` | Rebuild from source manually |
| Phase 1 base | Gentoo install medium | LFS 12.4 cross-toolchain |

The Gentoo script is the faster, more practical path for daily use. This script
is for learning exactly what the Gentoo script does under the hood, or for
running a system where every binary has a known build provenance.
