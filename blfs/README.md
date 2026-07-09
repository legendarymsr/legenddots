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

**Total wall-clock time on MacBook Air 6,2: ~30–40 hours across both phases.**
LLVM is the overwhelming bottleneck in Phase 2.

### Phase 1 — LFS base system (~8–12 hours)

| Step | What | Estimated time |
|------|------|----------------|
| Disk | Partition + format | ~1 min |
| Sources | Download ~80 tarballs | ~20–60 min (network speed) |
| Phase 1a | Cross-toolchain (binutils, gcc p1, glibc, libstdc++) | ~45 min |
| Phase 1b | Temporary tools (bash, coreutils, gcc p2, etc.) | ~60 min |
| Phase 1c | Base system in chroot (~75 packages) | ~4–6 h |
| Kernel | Linux 6.16.1 with MacBook hardware config | ~30 min |
| rEFInd | Bootloader | ~2 min |

### Phase 2 — BLFS desktop (~20–30 hours)

| Step | Package(s) | Estimated time |
|------|------------|----------------|
| 1 | D-Bus | ~3 min |
| 2 | PCRE2 | ~2 min |
| 3 | libffi | ~1 min |
| 4 | GLib | ~8 min |
| 5–8 | libpng, libjpeg-turbo, libtiff, libwebp | ~5 min |
| 9 | libdrm | ~2 min |
| 10–11 | Wayland + wayland-protocols | ~3 min |
| 12–13 | xkeyboard-config + libxkbcommon | ~3 min |
| 14 | pixman | ~2 min |
| 15–17 | FreeType (×2) + HarfBuzz | ~10 min |
| 18 | fontconfig | ~3 min |
| 19–22 | Cairo, Pango, gdk-pixbuf, ATK | ~12 min |
| 23 | at-spi2-core | ~3 min |
| 24 | GTK+ 3 | ~20 min |
| 25 | Rust toolchain | ~5 min (downloads pre-built) |
| 26 | librsvg | ~8 min |
| **27** | **LLVM 18** | **~6–10 hours** |
| 28 | Mesa (iris + crocus + Vulkan) | ~45 min |
| 29–32 | seatd, polkit, PipeWire, WirePlumber | ~15 min |
| 33–34 | niri, alacritty | ~25 min |
| 35–43 | waybar, fuzzel, swaylock, swaybg, dunst, grim, slurp, wl-clipboard, brightnessctl | ~25 min |
| 44 | fastfetch | ~3 min |
| 45 | Fonts | ~2 min |
| 46–47 | User setup + hardware config | ~1 min |

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
