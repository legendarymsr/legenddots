# LFS 12.4 + BLFS Desktop Setup — KVM/QEMU (x86_64, 2 vCPU, 4 GB) / Niri + Wayland

One script, two phases. Phase 1 runs from a Gentoo host and builds a complete
Linux From Scratch 12.4 base system on a target disk. Phase 2 runs inside that
LFS system and builds the full Niri + Wayland desktop stack from source.

The script detects which phase to run automatically — the first invocation
(from the Gentoo host) builds the base system and exits with reboot instructions;
the second invocation (booted into LFS) builds the desktop.

---

## Prerequisites

### Phase 1 — Gentoo host requirements

Install all required tools before running the script:

```sh
# Core build tools (most already installed on Gentoo)
emerge -av sys-devel/gcc sys-devel/make sys-devel/bison \
           sys-devel/flex sys-apps/gawk sys-devel/m4

# Disk tools
emerge -av sys-block/parted sys-fs/dosfstools sys-fs/e2fsprogs \
           sys-apps/util-linux

# Downloader (wget or curl — either is fine, the script detects both)
emerge -av net-misc/wget

# Bootloader (optional — can be installed and run later after booting LFS)
emerge -av sys-boot/refind
```

| Tool | Package | Used for |
|------|---------|----------|
| gcc, g++ | `sys-devel/gcc` | cross-toolchain |
| make, bison, flex, gawk, m4 | `sys-devel/*`, `sys-apps/gawk` | build tools |
| perl, python3 | `dev-lang/perl`, `dev-lang/python` | build scripts |
| tar, xz | `app-arch/tar`, `app-arch/xz-utils` | archives |
| parted | `sys-block/parted` | disk partitioning |
| mkfs.fat / mkdosfs | `sys-fs/dosfstools` | EFI partition |
| mkfs.ext4, mkswap, blkid | `sys-fs/e2fsprogs`, `sys-apps/util-linux` | root/swap |
| wget or curl | `net-misc/wget` | downloading sources |
| refind-install | `sys-boot/refind` | bootloader (optional) |

### Phase 2 — LFS environment requirements

Everything needed for Phase 2 is already built during Phase 1 (wget, git, curl,
cmake, meson, ninja, zsh, doas, openssl). Nothing extra is required.

---

## Target Hardware

This is a KVM/QEMU virtual machine — half the resources of the MacBook Air 6,2
host it runs on.

| Component | Detail |
|-----------|--------|
| vCPU      | 2 (half of host's 4 threads) |
| RAM       | 4 GB (half of host's 8 GB) |
| GPU       | virtio-gpu — Mesa `virgl` + `swrast` drivers |
| Network   | virtio-net |
| Storage   | virtio-blk (typically `/dev/vda`) |
| Audio     | virtio-sound or emulated HDA — PipeWire handles it |

Build flags:

```sh
CFLAGS="-march=x86-64 -O2 -pipe"
CXXFLAGS="-march=x86-64 -O2 -pipe"
MAKEFLAGS="-j2"
```

`-march=x86-64` is used instead of `-march=haswell` because the CPU features
exposed to the VM depend on the QEMU `-cpu` argument. If you launch with
`-cpu host`, you can safely change this to `-march=haswell`.

---

## QEMU Launch Command

A minimal QEMU command to boot the installed disk:

```sh
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 2 \
  -m 4G \
  -drive file=/path/to/lfs.img,if=virtio \
  -device virtio-gpu \
  -display gtk,gl=on \
  -device virtio-net,netdev=net0 \
  -netdev user,id=net0 \
  -device virtio-rng \
  -bios /usr/share/ovmf/OVMF.fd
```

`-display gtk,gl=on` enables virgl 3D acceleration on the host side.
Without `gl=on`, Mesa falls back to `swrast` (software rendering) which
is functional but slow for a compositor.

---

## Usage

### Phase 1 — from Gentoo host (as root)

```sh
git clone https://github.com/legendarymsr/legenddots ~/legenddots

# Set the target disk — for a QEMU raw image, pass the image file or
# the /dev/vdX device if attaching a real disk to the VM
export LFS_DISK=/dev/vdb

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

Times are wall-clock estimates for a 2 vCPU / 4 GB KVM VM (`MAKEFLAGS=-j2`).
**Total across both phases: ~50–70 hours.** LLVM is the overwhelming bottleneck.
RAM is tight during the LLVM build — the VM may swap; keep the host load low.

### Phase 1 — LFS base system (~12–20 hours)

| Step | What | Time |
|------|------|------|
| Disk | Partition + format | ~1 min |
| Sources | Download ~90 tarballs | ~20–60 min (network) |
| **Cross-toolchain** | | |
| | binutils pass 1 | ~8 min |
| | gcc pass 1 | ~18 min |
| | Linux API headers | ~1 min |
| | glibc 2.42 | ~30 min |
| | libstdc++ pass 1 | ~8 min |
| **Temporary tools** | (run as `lfs` user) | |
| | m4, ncurses, bash, coreutils, diffutils, file, findutils | ~15 min |
| | gawk, grep, gzip, make, patch, sed, tar, xz | ~8 min |
| | gettext (tools only) | ~8 min |
| | binutils pass 2, gcc pass 2 | ~30 min |
| **Chroot — base packages** | | |
| | glibc (final), zlib, bzip2, xz, zstd | ~35 min |
| | file, readline, m4, bc, flex, tcl | ~12 min |
| | binutils (final) | ~18 min |
| | mpfr, gmp, mpc, attr, acl, libcap, libxcrypt, shadow | ~12 min |
| | **gcc 15.2.0 (final)** | **~40 min** |
| | ncurses, sed, psmisc | ~8 min |
| | gettext, grep, bash, libtool, gdbm, gperf, expat | ~15 min |
| | inetutils, less, perl, XML-Parser, intltool | ~15 min |
| | autoconf, automake, openssl | ~12 min |
| | kmod, elfutils, libffi | ~8 min |
| | Python 3.13.7 | ~15 min |
| | flit_core, wheel, markupsafe, jinja2, packaging, setuptools | ~8 min |
| | ninja, meson | ~5 min |
| | coreutils, check, diffutils, gawk, findutils, groff | ~12 min |
| | gzip, iproute2, kbd, libpipeline, make, patch, tar | ~8 min |
| | vim | ~8 min |
| | eudev, man-db, procps, e2fsprogs | ~12 min |
| | sysklogd, sysvinit | ~3 min |
| | wget, curl, git, zsh, cmake, doas | ~22 min |
| | System config (fstab, inittab, locale, etc.) | ~1 min |
| **Kernel** | Linux 6.16.1, KVM/virtio config | ~45 min |
| **rEFInd** | Bootloader install | ~2 min |

### Phase 2 — BLFS desktop (~35–50 hours)

| Step | Package | Time |
|------|---------|------|
| 1 | D-Bus | ~5 min |
| 2 | PCRE2 | ~3 min |
| 3 | libffi | ~2 min |
| 4 | GLib | ~12 min |
| 5 | libpng | ~3 min |
| 6 | libjpeg-turbo | ~3 min |
| 7 | libtiff | ~5 min |
| 8 | libwebp | ~3 min |
| 9 | libdrm | ~3 min |
| 10 | Wayland | ~3 min |
| 11 | wayland-protocols | ~2 min |
| 12 | xkeyboard-config | ~2 min |
| 13 | libxkbcommon | ~5 min |
| 14 | pixman | ~5 min |
| 15 | FreeType (without HarfBuzz) | ~5 min |
| 16 | HarfBuzz | ~12 min |
| 17 | FreeType (with HarfBuzz) | ~5 min |
| 18 | fontconfig | ~5 min |
| 19 | Cairo | ~8 min |
| 20 | Pango | ~6 min |
| 21 | gdk-pixbuf | ~6 min |
| 22 | ATK | ~5 min |
| 23 | at-spi2-core | ~5 min |
| 24 | GTK+ 3 | ~30 min |
| 25 | Rust toolchain (rustup, pre-built) | ~8 min |
| 26 | librsvg | ~12 min |
| **27** | **LLVM 18** | **~10–16 h** |
| 28 | Mesa (virgl + swrast) | ~60 min |
| 29 | seatd | ~3 min |
| 30 | polkit | ~8 min |
| 31 | PipeWire | ~12 min |
| 32 | WirePlumber | ~8 min |
| 33 | niri (`cargo build --release`) | ~22 min |
| 34 | alacritty (`cargo build --release`) | ~15 min |
| 35 | waybar | ~12 min |
| 36 | fuzzel | ~5 min |
| 37 | swaylock | ~5 min |
| 38 | swaybg | ~3 min |
| 39 | dunst | ~5 min |
| 40 | grim | ~3 min |
| 41 | slurp | ~3 min |
| 42 | wl-clipboard | ~3 min |
| 43 | brightnessctl | ~2 min |
| 44 | fastfetch | ~5 min |
| 45 | Fonts | ~3 min |
| 46 | User setup + dotfile symlinks | ~1 min |
| 47 | KVM/QEMU hardware setup | ~1 min |

---

## What Gets Built

### Phase 1 — LFS base

A standard LFS 12.4 system: cross-toolchain targeting `x86_64-lfs-linux-gnu`,
~75 final packages (glibc, gcc, shadow, eudev, sysvinit, etc.), Linux 6.16.1
kernel built with virtio drivers for KVM. Extras added beyond the standard
LFS book: wget, curl, git, zsh, cmake, doas.

### Phase 2 — Desktop stack

**Graphics:** Mesa built with `virgl` (virtio-gpu 3D acceleration via the host
GPU) and `swrast` (software fallback). GLX is disabled — pure Wayland. LLVM is
required for virgl shader compilation. No Vulkan — virtio-gpu does not expose
a Vulkan ICD without additional setup.

`virgl` requires the QEMU host to launch with `-display gtk,gl=on` or
`-display sdl,gl=on`. Without host-side OpenGL, Mesa silently falls back to
`swrast` (llvmpipe), which works but will be noticeably slower for anything
GPU-accelerated.

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

## Kernel — virtio config

The kernel is built with virtio drivers instead of hardware-specific ones:

| Driver | Config | Purpose |
|--------|--------|---------|
| `virtio-pci` | `CONFIG_VIRTIO_PCI` | PCI transport for all virtio devices |
| `virtio-blk` | `CONFIG_VIRTIO_BLK` | Disk (`/dev/vda`) |
| `virtio-net` | `CONFIG_VIRTIO_NET` | Network |
| `virtio-gpu` | `CONFIG_DRM_VIRTIO_GPU` | Display / DRM node |
| `virtio-input` | `CONFIG_VIRTIO_INPUT` | Keyboard, mouse |
| `virtio-console` | `CONFIG_VIRTIO_CONSOLE` | Serial console |
| `virtio-balloon` | `CONFIG_VIRTIO_BALLOON` | Memory ballooning |
| `virtio-rng` | `CONFIG_HW_RANDOM_VIRTIO` | Entropy (faster boot) |
| 9P / virtfs | `CONFIG_9P_FS`, `CONFIG_NET_9P_VIRTIO` | QEMU shared folders |

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

## Differences from the bare-metal (MacBook Air) build

| | MacBook Air 6,2 | KVM (2 vCPU, 4 GB) |
|--|--------|------------|
| CPU flags | `-march=haswell` | `-march=x86-64` |
| Parallel jobs | `-j3` | `-j2` |
| GPU driver | `iris` + `crocus` (Intel i915) | `virgl` + `swrast` |
| Vulkan | ANV (Intel) | none |
| Kernel drivers | i915, HDA Cirrus, SATA AHCI, HID Apple, BCM WiFi | virtio-pci/blk/net/gpu/input |
| WiFi | BCM4360 (proprietary `wl` module) | virtio-net (no setup needed) |
| Backlight | brightnessctl + udev rules | not applicable |
| Step 47 | Apple/Broadcom hardware quirks | virtio-gpu udev permissions |
| LLVM build time | ~6–10 h | ~10–16 h |
| Total build time | ~30–40 h | ~50–70 h |
