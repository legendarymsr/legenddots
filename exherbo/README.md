# exherbo — Exherbo Linux installer (cave / paludis, UEFI x86_64)

A from-scratch installer for [Exherbo Linux](https://exherbo.org) — a
source-based, exheres-0 distro built around the **cave**/**paludis** package
mover. Same shape as `gentoo/install.sh` and `kiss/install.sh`: partition →
unpack a stage → fstab → chroot → sync & build.

> **One caveat up front — Exherbo is systemd-first.** This is the *only* systemd
> system in legenddots. If you want no-systemd, that's exactly what `gentoo/`
> (OpenRC), `kiss/` and `blfs/` are for. Exherbo can technically run other inits,
> but systemd is the supported path, so this installer uses it.

> **Heads up:** source-based — it compiles a kernel and toolchain bits, so it
> takes a while. It **wipes the target disk** and is **UEFI-only**.

## Just want to try it? (no install)

Already on Gentoo — or any Linux — and can't be bothered to repartition? Skip the
whole install. `try.sh` unpacks a stage into a directory and chroots you in to
play with cave/paludis. No partitioning, no bootloader, no reboot, fully
removable:

```sh
doas ./try.sh          # download a stage + drop into an Exherbo chroot
#   inside: cave sync · cave show arbor · cave resolve -x nano · Ctrl-D to leave
doas ./try.sh --enter  # re-enter later (no re-download)
doas ./try.sh --clean  # unmount + delete it, no trace on your host
```

Since you already run a source distro, **exheres will feel like ebuilds and cave
like portage** — this is the zero-commitment way to kick the tyres before (or
instead of) a real install.

## Install it in a VM (KVM)

Want a real, bootable install without touching your disk? `run-vm.sh` is one
command — it finds your OVMF firmware, makes the disk + NVRAM, **auto-downloads
the Gentoo minimal ISO** the first time, and boots. Run it once to install, then
again to boot what you installed.

```sh
doas emerge -av app-emulation/qemu sys-firmware/edk2-bin
doas usermod -aG kvm legend

./run-vm.sh
```

First run drops you into the Gentoo minimal live env — there, run
`DISK=/dev/vda ./install.sh` (the virtio disk is `/dev/vda`). After that,
`./run-vm.sh` with no args boots the installed system; `./run-vm.sh install`
forces the installer again, and `./run-vm.sh /path/to/other.iso` uses a specific
ISO instead of the default.

Tunable via env: `MEM=8G CPUS=4 DISK_SIZE=30G ISO_URL=… ./run-vm.sh`. The guest is
UEFI (OVMF) so the installer's `/sys/firmware/efi` check passes; networking is
user-mode NAT. If qemu lacks `gtk`/`sdl` it falls back to VNC on
`localhost:5900`.

## Run it

From any Linux live environment, as root. It needs a working network (stage
download, `cave sync`), so pick the live medium by how you get online — the same
picks as `kiss/`: **EndeavourOS** live ISO for wifi, the **Gentoo Minimal
Installation CD** for ethernet. Any live image works.

```sh
# persistent session so the build survives a disconnect (Ctrl-a d detaches)
screen -DR exherbo

git clone https://github.com/legendarymsr/legenddots
cd legenddots/exherbo
# defaults: /dev/sda, doas, hostname 'exherbo', America/New_York, en_US.UTF-8
DISK=/dev/sda ./install.sh
```

`install.sh` (host side) partitions `512M EFI + 4G swap + rest root`, downloads
and **sha256-verifies** the current x86_64 stage, unpacks it, writes `/etc/fstab`
from real UUIDs, binds the pseudo-filesystems, then runs `exherbo-setup.sh` in a
clean-environment (`env -i`) chroot.

`exherbo-setup.sh` (in chroot) sets hostname/timezone/locale, runs **`cave
sync`**, wires DHCP via `systemd-networkd`, **builds a kernel** (`sys-kernel/linux`
+ `dracut`), installs **GRUB** (`--removable`, so a Mac's firmware finds it),
sets up doas/sudo, and creates users.

> **Editing files:** `vi` (vim) is in the stage already; `nano` isn't until you
> `cave resolve -x app-editors/nano`, so use `vi` in the chroot.

## Knobs (environment variables)

| var | default | meaning |
|-----|---------|---------|
| `STAGE_FILE` | `exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz` | which stage to unpack; other arches/variants at [stages.exherbo.org](https://stages.exherbo.org/) (set `STAGE_BASE` too) |
| `VERIFY` | `true` | check the stage against its published `.sha256` |
| `DISK` | `/dev/sda` | disk to wipe (MacBook Air 6,2) |
| `PRIV_ESC` | `doas` | `doas` or `sudo` for the installed system |
| `HOSTNAME_` | `exherbo` | hostname |
| `TIMEZONE` | `America/New_York` | `/usr/share/zoneinfo/...` |
| `LOCALE` | `en_US.UTF-8` | set via `eclectic locale` + `/etc/locale.conf` |

## cave / paludis in 60 seconds

Exherbo's package mover is **cave**; packages are **exheres-0** (bash-based, like
Gentoo ebuilds but stricter), and repos are git trees synced with `cave sync`.

```sh
cave sync                       # sync every configured repo
cave resolve -x <spec>          # resolve dependencies and install (-x = execute)
cave resolve -x world           # update the whole system
cave show <spec>                # info about a package
cave resolve repository/<name>  # add another repo, then `cave sync`
```

- Options (the USE-flag equivalent) live in **`/etc/paludis/options.conf`**;
  repositories in `/etc/paludis/repositories/*.conf`. The stage ships working
  defaults with the core **`arbor`** repo.
- `eclectic` manages alternatives (locale, the kernel symlink, etc.), like
  Gentoo's `eselect`.

## After boot

- **Desktop:** add one with cave, e.g. a WM + terminal from the `x11` repos
  (`cave resolve -x x11-wm/… x11-terms/…`). The niri/bspwm rices in this repo are
  a starting point.
- **MacBook Air wifi:** the BCM4360 needs the proprietary `wl`
  (`net-wireless/broadcom-sta`) out-of-tree driver — build it against your kernel
  and load `wl`. Ethernet / USB-tether work out of the box.
- **Kernel:** the installer uses `defconfig`; for this Mac, `make menuconfig` in
  `/usr/src/linux-*` to enable i915 + SIMPLEDRM before rebuilding.

## Sources

- Install guide: <https://exherbo.org/docs/install-guide.html>
- Stages: <https://stages.exherbo.org/>
- cave / paludis docs: <https://paludis.exherbo.org>
