# GNU/Linux-libre From Scratch — a 100% free system

A fully [FSDG](https://www.gnu.org/distros/free-system-distribution-guidelines.html)-compliant
GNU/Linux built entirely from source: **Linux-libre** kernel, **GNU Shepherd**
init, **Xorg + ratpoison**, **GNU IceCat**, **GNU Emacs**. No nonfree firmware,
no binary blobs, no proprietary software anywhere in the stack.

One script, two phases — the same shape as `../blfs/setup`, but every choice is
the free-software one.

```sh
# Phase 1 — from a host distro, as root (builds the base onto a target disk):
LFS_DISK=/dev/vdb bash ~/legenddots/libre/setup

# Phase 2 — booted into the new system, as root (builds the desktop):
bash ~/legenddots/libre/setup
```

---

## Why VM-only

This is the important part. A libre kernel is a *deblobbed* kernel — the FSF's
`linux-libre` strips every piece of nonfree firmware the mainline kernel ships.
On real hardware that firmware is often load-bearing:

- The MacBook Air's **Broadcom BCM4360 WiFi** needs the nonfree `wl` blob — gone.
- Intel **CPU microcode** and **GPU firmware** — gone.
- Most modern WiFi/GPU/NIC hardware won't work without its blob.

A **virtio VM needs none of it.** virtio-blk, virtio-net, virtio-gpu, and
virtio-input are all pure in-tree free drivers with zero firmware. So a KVM/QEMU
guest is the one place a 100%-free kernel runs with full functionality — which
makes it the *ideal* target for a libre system, not a compromise.

Bare metal on the MacBook Air is what `../blfs` is for (which knowingly uses the
nonfree `wl` blob to get WiFi). This build is the opposite philosophy: freedom
first, VM-only.

---

## What's in it (and why each is the free choice)

| Layer | Choice | Free-software rationale |
|-------|--------|------------------------|
| Kernel | **Linux-libre 6.16** | Deblobbed by the FSF/FSFLA; no nonfree firmware |
| Init | **GNU Shepherd** | The GNU project's own init (Guile Scheme), as used by Guix |
| libc | **glibc** | GNU C Library |
| Display | **Xorg** | X.Org server — free; ratpoison/IceCat/Emacs are X11 |
| WM | **GNU ratpoison** | GNU keyboard-driven, screen-style window manager |
| Browser | **GNU IceCat** | FSF's fully-free Firefox derivative (no nonfree addons/telemetry) |
| Editor | **GNU Emacs** | The GNU editor, Lucid/Athena X toolkit build |
| Terminal | **xterm** | X.Org terminal emulator |
| Audio | **ALSA** | Free; no PulseAudio required |
| GL | **Mesa** (virgl + swrast) | Free OpenGL; virtio-gpu 3D via the host, llvmpipe fallback |
| Fonts | **DejaVu + GNU FreeFont** | Freely licensed font families |
| Bootloader | rEFInd | (the one pragmatic non-GNU piece; swap for GRUB if you want full GNU) |

---

## GNU Shepherd as PID 1

Instead of SysVinit, `/sbin/init` is a thin wrapper that execs Shepherd, which
reads its service graph from `/etc/shepherd/init.scm` (Guile Scheme). The
bootstrap chain built in phase 1 is:

```
libatomic_ops → bdw-gc → libunistring → GNU Guile → GNU Shepherd
```

(`gmp` and `libffi` come from the base build.) The default `init.scm` brings up
the pseudo-filesystems, remounts root, enables swap, sets the hostname, starts
`udevd`, and runs a getty on tty1–tty3. Extend it by editing `/etc/shepherd/init.scm`
and defining more `<service>` objects — that's the whole point of Shepherd:
services are first-class Scheme values.

---

## Build order & time

Phase 1 is a standard LFS-style base build (cross-toolchain → temp tools →
chroot base), identical to `../blfs` except: **Linux-libre** instead of Linux,
and **Guile+Shepherd** instead of SysVinit.

Phase 2 (the desktop) is the long pole. All estimates below assume a **2 vCPU
VM** (`MAKEFLAGS=-j2`). The two RAM columns matter because the heavy links
(LLVM, Mesa, Emacs, IceCat) swap on 4 GB and don't on 8 GB — swapping to a
virtio disk is what stretches the 4 GB times.

### Per-group estimates

| Group | 4 GB RAM | 8 GB RAM |
|-------|---------:|---------:|
| **Phase 1** — LFS base (toolchain, temp tools, chroot, Linux-libre, Shepherd) | ~14–20 h | ~12–16 h |
| Foundation (expat, image libs, freetype, fontconfig, harfbuzz) | ~45 min | ~40 min |
| Xorg proto + ~30 X libraries (built in a loop) | ~50 min | ~45 min |
| Keyboard + input (libxkbcommon, libinput) | ~15 min | ~15 min |
| **LLVM 18** (the single worst package) | **~13–18 h** (swaps) | **~10–14 h** |
| Mesa (virgl + swrast) | ~75 min | ~55 min |
| xorg-server + xinit + drivers | ~35 min | ~30 min |
| Fonts | ~5 min | ~5 min |
| xterm, **ratpoison**, GnuTLS | ~20 min | ~20 min |
| **GNU Emacs** | ~45–60 min | ~30–45 min |
| ALSA | ~10 min | ~10 min |
| **GNU IceCat** | **skipped** (needs ~8 GB — see below) | **~4–7 h** |
| xdm, user + dotfiles | ~15 min | ~15 min |

### Totals

| Configuration | Total wall-clock | Browser? |
|---------------|-----------------:|----------|
| **4 GB VM** | **~32–44 h** | IceCat auto-skipped; use Emacs `eww` |
| **8 GB VM** (no IceCat) | **~26–36 h** | IceCat auto-skipped only if you have <7 GB |
| **8 GB VM** (with IceCat) | **~30–43 h** | full GNU IceCat |

LLVM alone is roughly a third to a half of the whole build; if you only have one
long unattended window, that's the step to expect to sit through. The 8 GB
figures are lower *despite* also building IceCat because nothing swaps — on
4 GB, LLVM/Mesa/Emacs each lose time paging to the virtio disk.

Checkpointed to `/etc/libre-setup.state`; re-running resumes where it stopped, so
you can build across several sessions. Force one step to rerun with
`sed -i '/^emacs$/d' /etc/libre-setup.state`.

---

## The IceCat caveat (read before you count on a browser)

**IceCat is a Firefox-class build.** Two honest problems on a small VM:

1. **RAM.** Linking `libxul` wants roughly **8 GB**. The script detects total
   memory and *skips* IceCat with a warning if you have less than ~7 GB, so a
   4 GB VM finishes the rest of the desktop instead of thrashing to death.
   Give the VM 8 GB (or a large swapfile) and re-run to actually build it.
2. **Toolchain.** IceCat needs Rust (`rustc`/`cargo`), Node.js, `cbindgen`, and
   `nasm` — none of which are in the base system, and all of which are large
   builds in their own right. The script writes a working `.mozconfig` and runs
   `./mach build`, but you must have that toolchain present first. Building it
   from source is a project unto itself; the pragmatic path is to add Rust/Node
   before the IceCat step (or build IceCat on a beefier host and copy it in).

If you just want a working libre desktop without the Firefox ordeal, everything
up to IceCat gives you Xorg + ratpoison + Emacs + xterm, and Emacs's `eww` is a
perfectly usable built-in libre web browser for light browsing.

---

## Using it

Boot the VM, log in as **`gnu`** (password `libre`) on tty1. X starts
automatically into **ratpoison**. Ratpoison is keyboard-driven; the prefix key
is **C-t** (Control-t), screen-style:

| Key | Action |
|-----|--------|
| `C-t c` | new xterm |
| `C-t e` | GNU Emacs |
| `C-t b` | GNU IceCat |
| `C-t w` | list windows |
| `C-t n` / `C-t p` | next / previous window |
| `C-t ?` | help |

Config lives in `~/.ratpoisonrc`, `~/.xinitrc`, and `~/.Xresources` — edit and
`C-t :source ~/.ratpoisonrc` to reload.

### Default credentials

| Account | Password |
|---------|----------|
| gnu | `libre` |
| root | `legendary123` |

Change both immediately: `passwd gnu`, `passwd root`.

---

## QEMU launch

```sh
qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 8G \
  -drive file=/path/to/libre.img,if=virtio \
  -device virtio-gpu -display gtk,gl=on \
  -device virtio-net,netdev=n0 -netdev user,id=n0 \
  -device virtio-rng \
  -bios /usr/share/ovmf/OVMF.fd
```

`-m 8G` is deliberate — that's the RAM IceCat's link needs. Drop to `-m 4G` if
you're skipping IceCat. `-display gtk,gl=on` gives Mesa's virgl real host GL;
without it Mesa falls back to `swrast` (llvmpipe), which works but is slow.

---

## Differences from `../blfs`

| | `blfs` (bare-metal MacBook / KVM) | `libre` (VM-only) |
|--|--------|------------|
| Kernel | mainline Linux (+ nonfree `wl` blob on MBA) | **Linux-libre** (deblobbed) |
| Init | SysVinit | **GNU Shepherd** |
| Display | Wayland | **Xorg** |
| Compositor/WM | niri | **ratpoison** |
| Browser | Brave (nonfree) | **GNU IceCat** |
| Editor | Neovim | **GNU Emacs** |
| Firmware | uses nonfree blobs for WiFi | **none — 100% free** |
| Philosophy | pragmatic (working laptop) | freedom-first (FSDG) |
