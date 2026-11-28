# LFS 12.4 + BLFS desktop on a MacBook Air 6,2 (dual-boot with Gentoo)

`blfs/setup-mba` installs LFS 12.4 (sysvinit) and a Niri + Wayland desktop next
to an existing Gentoo install. It never changes the partition table and never
formats the EFI System Partition. It only uses partitions you point it at.

Hardware: early-2014 MacBook Air 6,2, 13", 1440x900, i5-4260U (Haswell), 8 GB,
Intel Haswell-ULT graphics, BCM4360 wifi, Apple keyboard.

## What it does

Phase 1 (on the Gentoo host, as root)
- checks the partitions (see Safety checks), formats the LFS partition only if
  it is empty or you confirmed it
- builds the LFS cross-toolchain, temporary tools and the final system in a chroot
- installs lfs-bootscripts, tzdata, the book patches, a book-correct /etc/group
- builds kernel 6.16.1 (BCM5974 trackpad, APPLESMC, hid_apple with `fnmode=2`,
  Cirrus audio, i915, EFI stub) and keeps its source in /usr/src
- builds the Broadcom `wl` driver from Debian's broadcom-sta source (patched for
  6.16) and blacklists brcmfmac/b43/ssb/bcma
- installs wpa_supplicant, dhcpcd and iw, and a `network` init script (wlan0)
- copies the kernel to `/EFI/LFS/` on the ESP and appends an "LFS 12.4" entry to
  the existing rEFInd `refind.conf` (backup: `refind.conf.pre-lfs`). Kernel
  command line uses `root=PARTUUID=...` because there is no initramfs.

Phase 2 (inside the LFS chroot, run automatically after Phase 1)
- builds the desktop: libxml2, D-Bus, GLib, GTK 3, Mesa 25.1.8 (crocus + swrast
  only), LLVM + clang 18.1.8 (clang is needed by niri's bindgen), libinput,
  libdisplay-info, PipeWire, WirePlumber, niri 25.08, Waybar 0.12.0 (niri
  modules, gtkmm 3), fuzzel, swaylock, swaybg, dunst, grim, slurp, fonts
- creates the user `legend`, links the dotfiles (including `~/.config/swaybg`),
  creates `XDG_RUNTIME_DIR` at boot and starts niri from tty1
- installs `links` so Super+B always has a browser (brave, then firefox, then links)

## Requirements on Gentoo

```
emerge -av sys-devel/gcc sys-devel/make sys-devel/bison sys-devel/flex \
  sys-devel/m4 sys-devel/patch sys-apps/gawk sys-apps/texinfo dev-lang/perl \
  dev-lang/python app-arch/tar app-arch/xz-utils net-misc/wget sys-fs/e2fsprogs \
  sys-apps/util-linux sys-boot/refind
```

`/bin/sh` must be bash. The host needs a working network for the whole run
(Phase 2 downloads crates and meson subprojects). Plan for about 40 GiB of disk
and 30-40 hours of build time; the LLVM + clang build is the longest part.

## Partitions

You create the partitions yourself, in free space, before running the script
(for example with `parted` or `gdisk` from Gentoo). Needed:

| Variable | Meaning |
|--|--|
| `LFS_PART` | empty partition for the LFS root, 40 GiB or more |
| `LFS_ESP` | the existing EFI System Partition (shared with Gentoo) |
| `LFS_SWAP` | optional swap partition; default is a 4 GiB swapfile |
| `LFS_CONFIRM_FORMAT` | partitions that already hold a filesystem and may be erased |
| `LFS_DESKTOP=no` | stop after the LFS base system |
| `LFS_WIFI_SSID`, `LFS_WIFI_PSK` | optional, written to wpa_supplicant.conf |

Safety checks: the script refuses whole disks, mounted partitions, active swap,
the running root partition, an ESP that is not type EFI System/FAT, and any
partition that already has a filesystem unless it is an ext4 labelled `LFS` or
listed in `LFS_CONFIRM_FORMAT`.

## Run

```
LFS_PART=/dev/sda5 LFS_ESP=/dev/sda1 bash ~/legenddots/blfs/setup-mba
```

Re-run the same command to resume; every step is checkpointed
(`/var/log/lfs-host.state` on Gentoo, `/tmp/lfs-chroot.state` and
`/etc/blfs-setup.state` in LFS).

Boot: reboot, pick "LFS 12.4" in rEFInd. Root password is `legendary123`, the
`legend` user password is `legendary`. Change both after the first login.

Wifi: edit `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`, or append the output
of `wpa_passphrase SSID PSK`, then `/etc/rc.d/init.d/network restart`.
