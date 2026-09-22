# kiss — KISS Linux installer (kiss-community fork)

A from-scratch installer for [KISS Linux](https://kisscommunity.org) — the
"Keep It Simple Stupid" source-based distro — targeting the maintained
[kiss-community](https://codeberg.org/kiss-community) fork on **UEFI x86_64**.
Same shape as `gentoo/install.sh`: partition → extract rootfs → fstab →
chroot → configure & build.

> **Heads up:** KISS is source-based. The rootfs tarball boots as-is, but this
> installer also **compiles a kernel and the bootloader from source**, so it
> takes a while. It **wipes the target disk** and is **UEFI-only**.

## Run it

From any Linux live environment, as root. It needs a working network (rootfs
download, `git clone`, ghcup), so pick the live medium by how you get online:

- **Wifi → [EndeavourOS](https://endeavouros.com) live ISO.** It ships
  NetworkManager/iwd, so `nmtui` (or `iwctl`) gets you connected in seconds —
  by far the least painful way to reach the internet from a live USB.
- **Ethernet → the [Gentoo Minimal Installation CD](https://www.gentoo.org/downloads/).**
  The small text-only admincd (**not** the graphical LiveGUI image) — wired
  networking just works with no setup, and it's the leaner source-build
  environment.

Any live Linux image works, though — these are just my picks by internet
situation. If you already have a live USB you like, use that; only the two above
are recommendations, not requirements.

```sh
git clone https://github.com/legendarymsr/legenddots
cd legenddots/kiss
# defaults: /dev/sda, doas, hostname 'kiss', America/New_York
DISK=/dev/sda ./install.sh
```

`install.sh` (host side) partitions `512M EFI + 4G swap + rest root`, downloads
and **sha256-verifies** the kiss-community rootfs tarball, unpacks it, writes
`/etc/fstab` from real UUIDs, then runs `kiss-setup.sh` inside the tarball's own
`kiss-chroot`. If `kiss-chroot` won't run the script directly, it prints the two
commands to do it by hand.

`kiss-setup.sh` (in chroot) sets hostname/timezone/hosts, clones the
kiss-community repos and sets `KISS_PATH`, builds the baseline
(`baseinit`, `e2fsprogs`, `dosfstools`, `eudev`, `linux-firmware`, `grub`,
`efibootmgr`, doas/sudo), **builds a kernel** (`defconfig`), installs **GRUB**
(`--removable`, so a Mac's firmware finds it), sets passwords / an optional
`wheel` user, and — unless you decline — builds the **XMonad desktop** for that
user (see below).

## Knobs (environment variables)

| var | default | meaning |
|-----|---------|---------|
| `KISS_VER` | `24.12.18` | rootfs release tag (check the [releases page](https://codeberg.org/kiss-community/repo/releases)) |
| `KISS_SHA256` | `4e5ece…30fd` | sha256 of the tarball (from the release notes; bump with `KISS_VER`). Empty = skip verify |
| `DISK` | `/dev/sda` | disk to wipe (MacBook Air 6,2) |
| `PRIV_ESC` | `doas` | `doas` or `sudo` for the installed system |
| `HOSTNAME_` | `kiss` | hostname |
| `TIMEZONE` | `America/New_York` | `/usr/share/zoneinfo/...` |
| `REBUILD_WORLD` | `false` | `true` = rebuild the whole base with your CFLAGS first (slow, the purist path) |
| `INSTALL_XMONAD` | `true` | build the XMonad desktop (Xorg + GHC) for the created user; `false` = base system only |
| `KSERIES` | `6.18` | LTS kernel series to build (see "Why this kernel" below) |
| `KVER` | newest of `KSERIES` | exact kernel version; auto-resolved to the latest point release of `KSERIES`, else set it yourself |

## Why this kernel (LTS, and 6.18 over 6.12)

KISS packages **no kernel** — you build your own — and this is a set-and-forget
box, so the installer pins a **Longterm (LTS)** series that gets security fixes
for *years*, rather than a mainline kernel that goes EOL roughly two months
after release.

Both **6.12** and **6.18** are current LTS kernels — and they share the **same
projected EOL, December 2028**. Since an older LTS buys no extra support
lifetime here, the default is the **newest LTS, 6.18**: identical longevity, but
newer drivers for this MacBook's hardware (i915 graphics, Broadcom wifi, etc.).
6.12 was the earlier, over-cautious pick; set `KSERIES=6.12` if you specifically
want it. The exact point release is resolved from kernel.org at build time, so
it's never stale.

## Desktop: XMonad (why, not dwm)

KISS is about **simple, not just small**. The obvious suckless pick, **dwm**,
is tiny — but you configure it by editing `config.h` in C and **recompiling the
window manager by hand** for every change. **XMonad** keeps the same tiling
minimalism, but the whole config is one Haskell file — `~/.xmonad/xmonad.hs`
that XMonad **recompiles itself** when you hit `Mod-q`. No C surgery to move a
keybind.

The config is **shared with the repo's `xmonad/` rice**: [`kiss/xmonad.hs`](xmonad.hs)
is a symlink to [`../xmonad/xmonad.hs`](../xmonad/xmonad.hs), so KISS and the Arch
setup never drift. See [`xmonad/README.md`](../xmonad/README.md) for the config
itself, the bar, and the TTY-style lock.

The one honest cost: XMonad needs **GHC (Haskell)** to build — the single heavy
dependency in this installer. KISS packages no `ghc`, so `kiss-setup.sh`
bootstraps the toolchain with **ghcup** (in the user's home, no root) and builds
`xmonad` + `xmonad-contrib` from Hackage with **cabal**. The running WM itself
stays tiny.

What it sets up, for the regular user you create:

- **Xorg** (`xorg-server`, `xinit`) plus the X11 dev headers cabal needs, and the
  tools the shared config spawns — `alacritty`, `rofi`, `dillo`, `picom`,
  `dunst`, `physlock` — from the KISS `xorg`/`community` repos.
- **GHC + cabal** via ghcup, then `xmonad` + `xmonad-contrib` + `xmobar`.
- The config at `~/.xmonad/xmonad.hs` and a `~/.xinitrc` that `exec xmonad`.
- The repo's Dillo config copied into `~/.dillo/` (Dillo reads only from there).
- `physlock` is set setuid so the `Mod-Shift-l` TTY lock works.

Then log in as that user and run **`startx`**. Default keys (Mod = **Super**):

| key | action |
|-----|--------|
| `Mod-Return` | open `alacritty` |
| `Mod-p` | `rofi` launcher |
| `Mod-w` | `dillo` browser |
| `Mod-Space` | cycle layout (tiled / full) |
| `Mod-j` / `Mod-k` | focus next / prev |
| `Mod-S-j` / `Mod-S-k` | move window down / up |
| `Mod-h` / `Mod-l` | shrink / grow master |
| `Mod-b` | toggle the bar |
| `Mod-S-l` | **lock** (physlock, TTY-style) |
| `Mod-S-c` | close window |
| `Mod-q` | **recompile this file & restart** |

Don't want it? Pass `INSTALL_XMONAD=false` for a base system only.

Two caveats: package names in the `xorg`/`community` repos drift between
revisions — the build loop tolerates a miss and names what to build by hand — and
**`alacritty` is Rust**, which cuts against the WD-40 "reject rust" ethos. To keep
a KISS box Rust-free, swap the terminal in `../xmonad/xmonad.hs` for `st` and
build that instead.

## Tuning the kernel

`defconfig` gives a generic bootable kernel. For this MacBook's hardware
(i915 graphics, Broadcom wifi, etc.), edit `kiss-setup.sh` to uncomment the
`make menuconfig` line, or run it by hand in the chroot before `make`. Want a
fully-free kernel? Swap the kernel.org URL for **linux-libre** (see `libre/`).

## Sources

- Canonical guide: <https://kisslinux.github.io/install>
- Community differences (repos, tarball host, signing): <https://kisscommunity.org/kiss/install/>
- Repos & rootfs releases: <https://codeberg.org/kiss-community/repo>

The kiss-community rootfs tarball is **not GPG-signed** and ships **no `.sha256`
asset** — the checksum is published in the release notes, so the installer
verifies against the `KISS_SHA256` value baked in above (update it whenever you
bump `KISS_VER`). Git commit signing (ssh) can be enabled per the community
guide if you want it.
