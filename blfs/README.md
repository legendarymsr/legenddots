# BLFS Desktop Setup — MacBook Air 6,2 / Niri + Wayland

Linux From Scratch gives you a base system. BLFS gives you everything
else. This script automates the "everything else" part — the full Niri +
Wayland desktop stack, built from source, tuned for Haswell, mirroring
the same software set as the Gentoo setup.

If you're wondering why you'd build a desktop by hand from tarballs instead
of just running `emerge` or `pacman`: you wouldn't, normally. LFS/BLFS is
a learning exercise and a provenance exercise. Every binary on this system
was compiled by your compiler, on your hardware, from source code you
fetched yourself. You can read every configure flag. You know exactly what
was linked and why. It's slow, deliberate, and completely transparent — the
opposite of clicking "install" and trusting a stranger's pre-built blob.

If that sounds like overkill, use the Gentoo script instead. If it sounds
like the point, read on.

---

## Prerequisites

This script expects an **LFS 12.x base system** already built and booted
(or chrooted into). The following must be present before running:

| Tool | Used for |
|------|----------|
| gcc, g++ | compiling everything |
| make, ninja | build systems |
| cmake ≥ 3.20 | cmake-based packages |
| meson ≥ 1.3 | meson-based packages (most of the stack) |
| pkg-config | dependency discovery |
| python3 | meson, some build scripts |
| perl | some build scripts |
| bison, flex | wayland, mesa |
| gperf | libxkbcommon |
| diffutils, patch | applying patches |
| wget | fetching source tarballs |
| git | cloning legenddots dotfiles |
| openssl | hashing passwords |
| zsh | user shell |

Mesa also requires `bison`, `flex`, `python3-mako` (pip install mako), and
`python3-yaml`. Install them before running if your LFS base is minimal.

---

## Target Hardware

Same machine as the Gentoo script:

| Component | Detail |
|-----------|--------|
| CPU       | Intel Core i5-4250U (Haswell, 4T, up to 2.6 GHz) |
| iGPU      | Intel HD Graphics 5000 — Mesa `iris` + `crocus` drivers |
| WiFi      | Broadcom BCM4360 — proprietary `wl` module, must be built separately |
| Audio     | Cirrus Logic CS4208 (Intel HDA) — PipeWire handles it |
| Storage   | Apple PCIe SSD (AHCI) |
| RAM       | 8 GB |

Build flags are set globally for this CPU:

```sh
CFLAGS="-march=haswell -O2 -pipe"
CXXFLAGS="-march=haswell -O2 -pipe"
MAKEFLAGS="-j3"
```

`-j3` on 4 threads leaves one free so the system stays responsive.
`-j4` on this RAM causes OOM under LLVM and Mesa's parallel link steps.

---

## Usage

Boot or chroot into your LFS system, clone legenddots, and run as root:

```sh
git clone https://github.com/legendarymsr/legenddots ~/legenddots
bash ~/legenddots/blfs/setup
```

The script is fully unattended after that. Source tarballs are downloaded
to `/sources/` as needed. Completed steps are checkpointed to
`/etc/blfs-setup.state` — if the build is interrupted, re-run the same
command and it picks up where it left off.

To reset a specific step and force it to rerun, remove its name from the
state file:

```sh
sed -i '/^mesa$/d' /etc/blfs-setup.state
bash ~/legenddots/blfs/setup   # re-runs mesa only
```

---

## Build Order & Estimated Time

Total wall-clock time on MacBook Air 6,2: **12–20 hours**.
LLVM is the overwhelming bottleneck — everything else is fast.

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
| 33–34 | niri, alacritty | ~25 min (Rust compile) |
| 35–43 | waybar, fuzzel, swaylock, swaybg, dunst, grim, slurp, wl-clipboard, brightnessctl | ~25 min |
| 44 | fastfetch | ~3 min |
| 45 | Fonts | ~2 min (downloads) |
| 46–47 | User setup + hardware config | ~1 min |

LLVM is unavoidable: Mesa's `iris` Gallium driver requires it for shader
compilation. There is no rust-free or llvm-free path to hardware-accelerated
graphics on Intel Haswell with this stack.

---

## What Gets Built

### Graphics stack

Mesa is built with:

```
-D platforms=wayland
-D gallium-drivers=iris,crocus,swrast
-D vulkan-drivers=intel
-D glx=disabled
-D egl=enabled
-D llvm=enabled
```

`iris` is the primary driver for Intel Haswell and newer. `crocus` covers
older Intel gen (Ivy Bridge, Sandy Bridge) and is included for completeness.
`swrast` is the software fallback. `vulkan-drivers=intel` gives you the
ANV Vulkan driver. GLX is disabled — this is a pure Wayland system.

### Wayland compositor

`niri` built from source via `cargo build --release`. Installed to
`/usr/bin/niri`. The niri config, waybar, fuzzel, dunst, swaylock, and
alacritty are all symlinked from the legenddots dotfile repo.

### Audio

PipeWire replaces PulseAudio. WirePlumber manages the session. Built
without systemd support — sessions are managed by elogind (or seatd for
seat management).

### Seat management

`seatd` runs as an OpenRC service and manages access to `/dev/input/*`,
`/dev/drm/*`, and `/dev/video*` for unprivileged Wayland compositors.
`legend` is added to the `seat` group. An OpenRC init script is written
to `/etc/init.d/seatd` and registered at boot.

### Rust toolchain

Installed via `rustup` to `/usr/share/rustup` and `/usr/share/cargo`, with
a profile drop-in at `/etc/profile.d/rust.sh`. Both `niri` and `alacritty`
use `cargo build --release --locked` against the versions pinned in their
respective `Cargo.lock` files. `librsvg` uses autotools + cargo internally
(the `./configure` wrapper calls cargo during build).

---

## Versions

All version numbers are set as variables at the top of `setup` and are
easy to update. Check the BLFS stable book for newer releases before
running:

```
https://www.linuxfromscratch.org/blfs/view/stable/
```

Packages not in the BLFS book (niri, fuzzel, swaylock, swaybg, grim,
slurp, wl-clipboard, brightnessctl, fastfetch) pull from their upstream
GitHub/Codeberg releases.

---

## WiFi — BCM4360

The Broadcom BCM4360 has no in-tree mainline driver. The proprietary `wl`
module (broadcom-sta) must be compiled against your running kernel. The
script writes the `/etc/modprobe.d/broadcom-sta.conf` blacklist but cannot
build the module automatically — the kernel headers must match whatever
kernel version is booted, which the script can't know at build time.

After booting your LFS system:

```sh
# Download broadcom-sta source (check for latest version)
wget https://www.lwfinger.com/downloads/hybrid-v35_64-nodebug-pcoem-6_30_223_271.tar.gz
tar -xf hybrid-v35_64-nodebug-pcoem-6_30_223_271.tar.gz
cd hybrid-v35_64-nodebug-pcoem-6_30_223_271

make -C /lib/modules/$(uname -r)/build M=$(pwd) modules
install -m 644 wl.ko /lib/modules/$(uname -r)/updates/
depmod -a
modprobe wl
```

Then configure NetworkManager:

```sh
rc-service NetworkManager start
nmtui   # or nmcli device wifi connect <SSID> password <pw>
```

For the install itself, tether your phone via USB — the `cdc_ether` or
`rndis_host` module handles USB tethering and needs no proprietary
firmware.

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

The script checks for `doas` and writes a minimal `/etc/doas.conf` if
found. doas is not in the standard LFS book — build it from source first
if you want it:

```sh
# OpenDoas
wget https://github.com/Duncaen/OpenDoas/releases/download/v6.8.2/opendoas-6.8.2.tar.gz
tar -xf opendoas-6.8.2.tar.gz && cd opendoas-6.8.2
./configure --prefix=/usr --sysconfdir=/etc --with-timestamp
make && make install
echo 'permit persist legend as root' > /etc/doas.conf
chmod 0400 /etc/doas.conf
```

Otherwise configure sudo with `%wheel ALL=(ALL:ALL) ALL` in
`/etc/sudoers.d/wheel`.

---

## Differences from the Gentoo setup

| | Gentoo | BLFS |
|--|--------|------|
| Package manager | Portage (`emerge`) | None — tarballs + build scripts |
| Binary cache | `FEATURES=buildpkg` | None |
| Resume support | `resume.sh` + state file | Same state-file pattern |
| LLVM build time | ~1.5 h (with ccache, O1) | ~6–10 h (cold, O2) |
| Kernel | Managed by portage | Bring your own from LFS |
| Updates | `emerge --update @world` | Rebuild from source manually |
| WD-40 (Rust trimming) | Profile fragment | N/A — Rust built explicitly |

The Gentoo script is the faster, more practical path for daily use. The
BLFS script is for understanding exactly what the Gentoo script is doing
under the hood, or for running a system where every binary has a known
build provenance.
