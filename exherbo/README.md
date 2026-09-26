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

Want a real, bootable install without touching your disk? `run-vm.sh` does the
whole thing in one command — **installs qemu + OVMF firmware** if they're missing,
adds you to the `kvm` group (and activates it for the session, no re-login),
makes the disk + NVRAM, **auto-downloads the Gentoo minimal ISO** the first time,
and boots.

```sh
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

**One command, and it does the rest.** It's *self-updating and resumable* — so
if a build step ever fails (a flaky mirror, a download that times out), you just
run the exact same command again and it continues where it left off:

- `./install.sh` — **auto**: fresh install on an empty disk, or **resume** an
  existing one (no wipe). On resume it re-mounts everything for you and re-enters
  the chroot to finish the build. Run it as many times as you need.
- `./install.sh fresh` — force a clean wipe + reinstall.
- `./install.sh resume` — explicitly re-enter an existing install and continue.

On each run it first `git pull`s the latest fixes and re-execs itself, so you're
never running a stale copy. A **fresh** run partitions `512M EFI + 4G swap + rest
root`, downloads and **sha256-verifies** the current x86_64 stage, unpacks it,
writes `/etc/fstab` from real UUIDs, binds the pseudo-filesystems, then runs
`exherbo-setup.sh` in a clean-environment (`env -i`) chroot. A **resume** run
skips straight to that last step.

`exherbo-setup.sh` (in chroot) sets hostname/timezone/locale, runs **`cave
sync`**, wires DHCP via `systemd-networkd`, **builds a kernel from kernel.org**
(Exherbo doesn't package one — only `linux-firmware` comes from cave), with the
disk/fs drivers built *in* so it boots with no initramfs, installs
**systemd-boot** (`bootctl` — Exherbo is systemd-first, so no grub/efibootmgr
needed), sets up doas (from the third-party `somasis` repo) or sudo, and creates
users.

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

## Exherbo vs Gentoo · cave/paludis vs portage

Exherbo was started around 2008 by ex-Gentoo developers who wanted Gentoo's
ideas rebuilt cleaner and stricter, without the accumulated cruft. The DNA is
shared — source-based, USE-flag-style configuration, bash-based package recipes
— but nearly every piece was redesigned.

### The distros

| | **Gentoo** | **Exherbo** |
|---|---|---|
| Package format | `ebuild` (EAPI-versioned bash) | `exheres-0` (bash, far stricter, structured) |
| Package manager | **Portage** (Python) | **Paludis**, driven by `cave` (C++) |
| Releases | stable **and** `~arch` testing keywords | rolling only — no stable branch |
| Cross-compile / multiarch | bolted on (`crossdev`) | first-class: target triples, subslots, built for it |
| Repositories | one big `::gentoo` tree + overlays | many small git repos + the `unavailable` meta-repo |
| Init | OpenRC default (systemd optional) | systemd-first |
| Config | rich profile tree, `/etc/portage/` | direct, `/etc/paludis/` (`options.conf`) |
| Scope | broad — many arches, huge package set, binhosts, big wiki | small, opinionated, source-only, sparse docs, power-user |

Short version: **Gentoo is the big, broad, well-documented one; Exherbo is the
small, strict, developer-focused one.** Exherbo ships fewer packages precisely
*because* its QA bar is higher — an exheres has to be clean.

### Portage vs Paludis (cave)

Both build from source, but they're different beasts:

- **Language & rigor.** Portage is Python; Paludis is **C++** with the `cave`
  frontend. Paludis' resolver is stricter — it refuses ambiguous or unsafe
  states rather than muddling through, where Portage is more permissive.
- **Options vs USE flags.** Gentoo's USE flags are mostly on/off, spread across
  `make.conf` + `package.use`. Exherbo's **options** are typed and can carry
  *values* — `symbols=split`, `jobs=2`, `work=tidyup` — build knobs with defined
  choices, kept in `/etc/paludis/options.conf`.
- **Commands.** `emerge` → `cave resolve`; `emerge --sync` → `cave sync`;
  `emerge -pv` → `cave resolve` (dry-run) / `cave show`; `eselect` → `eclectic`.
- **Repos.** Portage: one tree + `repos.conf`. cave: git repos synced with
  `cave sync`, third-party ones enabled with `cave resolve repository/<name>`.
- **History twist.** Paludis actually began as an *alternative package manager
  for Gentoo* (~2005) before its authors forked off to build Exherbo around it —
  so Paludis predates Exherbo, it was a Portage competitor first.

### Why they left — in their own words

A cluster of Gentoo developers left in 2007–2008, several of whom went on to
Exherbo. The mood of the time, from their own posts:

> It is now clear to me that Gentoo is not moving in the direction I had wished
> for, and the last council election indicates that most current Gentoo
> developers appear to be satisfied with this current direction.
> — **Bo Ørsted Andresen**, 2008

> I'm not sure I see the technical advancements that I'd like happening in
> Gentoo. That aside there're numerous non-technical problems behind the scenes
> that most devs probably acknowledge by now…
> — **Ingmar Vanhassel**, 2008

> I feel like my efforts are being stymied by the lack of overall technical
> progress and direction in the project.
> — **Mike Kelly**, 2007

> There's absolutely nothing for me to gain by being labelled an "official
> Gentoo developer", and an awful lot to lose.
> — **Ciaran McCreesh**, 2007

> Over 8 months this council has achieved little… Vote for anyone from this
> council again … vote for mediocrity at best.
> — **Richard Brown**, 2008

**TL;DR:** a chunk of Gentoo's own developers reckoned the project was going
downhill around 2007–08 — technically stagnant, politically messy — so they
walked and built Exherbo instead.

## After boot

- **Desktop:** add one with cave, e.g. a WM + terminal from the `x11` repos
  (`cave resolve -x x11-wm/… x11-terms/…`). The niri/bspwm rices in this repo are
  a starting point.
- **MacBook Air wifi:** the BCM4360 needs the proprietary `wl`
  (`net-wireless/broadcom-sta`) out-of-tree driver — build it against your kernel
  and load `wl`. Ethernet / USB-tether work out of the box.
- **Kernel:** built from kernel.org with `defconfig` + the disk/fs drivers forced
  in (virtio for the VM, AHCI/NVMe + vfat for the Mac) so it boots with no
  initramfs. For this Mac, `make menuconfig` in `/usr/src/linux-*` to add i915 +
  SIMPLEDRM before rebuilding, then re-copy `arch/x86/boot/bzImage` to
  `/boot/vmlinuz-*`.

## Sources

- Install guide: <https://exherbo.org/docs/install-guide.html>
- Stages: <https://stages.exherbo.org/>
- cave / paludis docs: <https://paludis.exherbo.org>
