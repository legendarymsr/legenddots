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

From any Linux live environment, as root:

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
(`--removable`, so a Mac's firmware finds it), and sets passwords / an optional
`wheel` user.

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
| `KVER` | `6.12.9` | kernel version to fetch from kernel.org |

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
