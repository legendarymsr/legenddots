# Gentoo Install Script — MacBook Air 6,2

If you're still on Windows: an OS that phones home by default, forces
updates at 3am, ships a keylogger called "Recall", sells your telemetry
to advertisers, and locks you into a walled garden owned by a company
that tried to embrace-extend-extinguish Linux for 20 years — close this
tab, uninstall it, and come back when you're serious.

If you're on a binary distro clicking "install" on precompiled blobs
you didn't ask for, built by people you don't know, with USE flags you
never chose — you can do better.

And if you're on a Chromebook: congratulations, you're technically
running Gentoo. ChromeOS is built on Gentoo. The portage package
manager, the USE flags, the entire foundation — all Gentoo, all the
way down. Google took the most customisable Linux distribution ever
made and used it to build a locked-down browser with a keyboard.
How does it feel to be running one of the most powerful and
configurable operating systems ever conceived, and all you can do
with it is open a tab?

Apple dropped this machine at macOS Big Sur and called it a day. A
perfectly capable Haswell i5 with years of life left in it, abandoned
because a corporation decided your hardware's expiry date for you.
Meanwhile they're charging you for a walled garden where you can't
install what you want, can't see what's running, and can't own your own
machine. Your MacBook Air is better than what Apple left it as.

Take it back. Run a kernel released this week. Build everything for
your exact CPU. Own your hardware completely.

Fully automated Gentoo installation script for the **MacBook Air 6,2
(Mid 2013, Intel Core i5-4250U)**. Everything built from source, tuned
for your exact hardware. Boot the live ISO, run the script, walk away.
No prompts. No binary packages. No Microsoft. No Apple. No compromises.

---

## Target Hardware

| Component | Detail                                          |
|-----------|-------------------------------------------------|
| CPU       | Intel Core i5-4250U (Haswell, 4T, up to 2.6GHz)|
| iGPU      | Intel HD Graphics 5000 (iris driver)            |
| WiFi      | Broadcom BCM4360 (proprietary `wl` driver)      |
| Audio     | Cirrus Logic CS4208 (Intel HDA)                 |
| Storage   | Apple PCIe SSD (AHCI, `/dev/sda`)               |
| Firmware  | Apple UEFI                                      |

---

## Usage

Boot the Gentoo minimal or LiveGUI ISO, tether your phone via USB for
internet (BCM4360 has no in-tree driver), then:

```sh
tmux new -s install   # so a dropped connection doesn't kill the build
bash install.sh
```

The script asks two questions up front, each with a 10-second timeout —
leave it untouched and it defaults to WD-40 enabled and doas:

```
Apply WD-40 (mask optional rust USE flag)? [Y/n] (10s, default: Y)
Privilege escalation tool? [doas/sudo] (10s, default: doas)
```

You can also skip the prompts entirely by setting the env vars before
running:

```sh
ENABLE_WD40=false PRIV_ESC=sudo bash install.sh
```

| Variable | Default | Options | Effect |
|----------|---------|---------|--------|
| `ENABLE_WD40` | `true` | `true` / `false` | Mask the optional `rust` USE flag via the WD-40 profile |
| `PRIV_ESC` | `doas` | `doas` / `sudo` | Privilege-escalation tool installed and configured |

After those two questions, the rest of the script runs fully
unattended. A full build takes roughly **4 hours**
on this hardware:

| Phase | Time |
|-------|------|
| Kernel | ~45 min |
| LLVM + clang (O1) | ~1.5 hrs |
| mesa (O1) | ~20 min |
| Desktop packages | ~45 min |
| Everything else | ~30 min |

LLVM, clang, and mesa build with `-O1` to cut compile time roughly in
half. ccache means any subsequent reinstall is significantly faster —
the script bumps ccache's max-size from its 5GiB default to 12GiB and
turns on compression, since a single LLVM+clang+mesa+kernel build cycle
can otherwise fill the default cache and start evicting entries before a
resumed/repeated install ever gets to reuse them.
LLVM stays at the same system-wide `MAKEOPTS=-j3` as everything else —
`--jobs=1` only stops *multiple packages* from building in parallel, it
doesn't cap how much RAM a single package's own parallel compile uses,
and LLVM/clang are memory-hungry enough per compile unit that pushing
just that package past `-j3` risks the same kind of OOM/freeze a higher
`--jobs` caused earlier.

`EMERGE_DEFAULT_OPTS` caps emerge at `--jobs=1` (one package built at
a time, `MAKEOPTS=-j3` inside that package) rather than building
several heavy packages in parallel. This machine doesn't have the RAM
to run multiple LLVM/clang/mesa/brave-browser-nightly compiles at
once — `--jobs=4` would spawn up to 12 concurrent compiler threads on
a 4-thread CPU, which thrashes swap hard enough to look like a frozen
machine.

### Resuming after a crash

If the machine freezes or loses power mid-install, reboot the live ISO,
tether internet again, and run:

```sh
bash resume.sh
```

`install.sh` checkpoints each of the 10 numbered steps to
`/etc/gentoo-install.state` inside the new root filesystem as it
completes them. `resume.sh` re-mounts the partitions `install.sh`
already created (it does **not** repartition or re-unpack stage3),
re-enters the chroot, and re-runs the install logic — steps already
marked done are skipped, so it picks up at whichever step was running
when it crashed. The `ENABLE_WD40`/`PRIV_ESC` choices from the original
run are reused automatically.

`resume.sh` regenerates `/tmp/inside.sh` fresh from the `install.sh`
sitting next to it before re-entering the chroot, rather than reusing
the stale copy from the original run — so if you `git pull` an updated
`install.sh` after a crash, the resumed run picks up that fix instead
of repeating the same failure. It also detects a kernel built before
the broadcom-sta `PREEMPT_RCU`/in-tree-driver fix (see below) and
automatically forces both the kernel and base_system steps to rerun in
that case, so you don't have to manually edit
`/etc/gentoo-install.state` yourself.

If neither `install.sh` is present next to `resume.sh` nor
`/mnt/gentoo/tmp/inside.sh` exists (e.g. the crash happened before
stage3 even finished unpacking), there's nothing to resume —
`resume.sh` will tell you to run `install.sh` again from scratch.

---

## Step-by-Step Walkthrough

What you'll actually see scroll by, in order.

**Prompts (10s timeout each, defaults shown):**

```
$ bash install.sh
Apply WD-40 (mask optional rust USE flag)? [Y/n] (10s, default: Y)

Privilege escalation tool? [doas/sudo] (10s, default: doas)

```

**Disk Management:**

```
── Disk Management
Creating new GPT entries.
The operation has completed successfully.
The operation has completed successfully.
The operation has completed successfully.
mke2fs 1.47.1 (20-May-2024)
Creating filesystem with 28311552 4k blocks and 7077888 inodes
```

**Stage3 unpack** (no header — just a progress bar):

```
######################################################################## 100.0%
```

**1. Portage sync & hardened profile:**

```
── Syncing portage tree...
>>> Syncing repository 'gentoo' into '/var/db/repos/gentoo'...
>>> Fetching 1 file...
>>> Syncing completed
 * Profile not changed.
```

**2-3. Keywords & make.conf** — written silently, no console output.

**4. Overlays:**

```
── Setting up overlays...
 * Repository guru
 * Location: /var/db/repos/guru
 * Added repository 'guru'

>>> Syncing repository 'hyproverlay' into '/var/db/repos/hyproverlay'...
>>> Syncing completed
```

**5. WD-40** (skipped if you answered `n` to the first prompt):

```
── Applying WD-40...
 * Repository local
 * Location: /var/db/repos/local
 * Added repository 'local'
```

Right after activating the profile, alacritty is unmasked again —
without this, step 7's emerge fails with:

```
!!! All ebuilds that could satisfy "x11-terms/alacritty" have been masked.
!!! One of the following masked packages is required to complete your request:
- x11-terms/alacritty-9999::gentoo (masked by: package.mask, missing keyword)
/var/db/repos/gentoo/profiles/features/wd40/package.mask:
# alacritty requires rust unconditionally
```

or, if declined:

```
── Skipping WD-40 (ENABLE_WD40=false)...
```

**6. Kernel:**

```
── Building kernel...
>>> Emerging (1 of 4) sys-kernel/gentoo-sources-6.x.x::gentoo
#
# configuration written to .config
#
  CC      arch/x86/boot/compressed/vmlinux
  LD      vmlinux
  GEN     .vmlinux.export.c
  INSTALL /boot/vmlinuz-6.x.x-gentoo
>>> Building initramfs...
```

**7. Base system:**

```
── Emerging base system...
>>> Emerging (1 of 24) sys-apps/pciutils-3.x.x::gentoo
>>> Emerging (2 of 24) sys-apps/usbutils-0.x.x::gentoo
...
>>> Emerging (24 of 24) sys-boot/refind-0.x.x::gentoo
```

**8. Desktop:**

```
── Emerging desktop...
>>> Emerging (1 of 16) gui-wm/niri-25.x.x::guru
>>> Emerging (2 of 16) gui-apps/waybar-0.x.x::guru
...
>>> Emerging (16 of 16) www-client/brave-browser-nightly-1.x.x.x::another-brave-overlay
```

**9. Localization & user:**

```
── Localizing and creating user...
 * Generating locales...
 *   en_US.UTF-8.UTF-8...            [ ok ]
 *   sv_SE.UTF-8.UTF-8...            [ ok ]
Cloning into '/home/legend/legenddots'...
remote: Enumerating objects: ...
```

**10. Finalize:**

```
── Finalizing...
Installing rEFInd on this disk...
Mounted EFI System Partition at /boot/efi
Copying rEFInd files...
Setting EFI boot entry...
rEFInd has been installed successfully.
 * rc-update add NetworkManager default ... [ ok ]
 * rc-update add bluetooth default       ... [ ok ]

── Done. The Hardened Kingdom of Legend is built.

Reboot now: umount -R /mnt/gentoo && reboot
```

---

## What It Does

### Disk layout (hardcoded, `/dev/sda` wiped)

| Partition | Size  | Filesystem | Mount       |
|-----------|-------|------------|-------------|
| sda1      | 512MB | FAT32      | /boot/efi   |
| sda2      | 8GB   | swap       | —           |
| sda3      | rest  | ext4       | /           |

### Profile & kernel

- Profile: `default/linux/amd64/23.0/hardened`
- Kernel: `sys-kernel/gentoo-sources` (hardened-sources was removed from
  the Gentoo tree in 2024/2025; manual hardening configs applied instead)
- Built with `make defconfig` + hardware-specific and security options,
  then `genkernel` for the initramfs

### make.conf highlights

```
COMMON_FLAGS="-march=haswell -O2 -pipe"
MAKEOPTS="-j3"
VIDEO_CARDS="intel iris"
LLVM_TARGETS="X86"
USE="udev elogind dbus wayland alsa -systemd -gnome -kde -qt5 -cups -pulseaudio -cuda -rocm -vdpau"
FEATURES="ccache"
ACCEPT_KEYWORDS="~amd64"
GENTOO_MIRRORS="https://ftp.lysator.liu.se/gentoo https://mirrors.dotsrc.org/gentoo"
```

`MAKEOPTS="-j3"` on 4 threads (one held back so the system stays usable
mid-compile) plus `EMERGE_DEFAULT_OPTS="--jobs=1 --load-average=3"` (one
package at a time, back off if load climbs) is the safe ceiling for 8GB
RAM — this combo replaced an earlier, more aggressive setting after it
caused an actual OOM freeze on this machine. `GENTOO_MIRRORS` points
distfile downloads at Lysator (Linköping, Sweden) first, falling back to
dotsrc.org (Denmark) — portage tries mirrors left-to-right per file.

### WD-40 (de-rust the profile)

Gentoo ships a `features/wd40` profile fragment that masks the optional
`rust` USE flag wherever a package can be built without it — fewer
packages pull in `dev-lang/rust`, which is a slow build. The script
creates a local profile (`local:wd40-hardened`) that inherits from both
`gentoo:default/linux/amd64/23.0/hardened` and `gentoo:features/wd40`
and activates it via `eselect profile set`.

This only suppresses *optional* Rust dependencies — it can't eliminate
Rust entirely. `x11-terms/alacritty` (in the base package list) is
itself written in Rust and needs `dev-lang/rust` regardless.

`features/wd40/package.mask` goes further than just the USE flag: it
blanket-masks packages that hard-require rust with no way to build
around it, alacritty included. The script unmasks alacritty
specifically via `/etc/portage/package.unmask/alacritty` right after
activating the profile, so the base-system emerge doesn't fail on a
masked package.

Toggle it with the `ENABLE_WD40` env var (default `true`):

```sh
ENABLE_WD40=false bash install.sh
```

### Overlays

| Overlay                | Provides                         |
|------------------------|----------------------------------|
| guru                   | niri · nerdfonts · misc apps     |
| hyproverlay            | xdg-desktop-portal-wlr           |
| another-brave-overlay  | brave-browser-nightly            |

### Base packages (step 6)

NetworkManager, bluez, broadcom-sta, elogind, pipewire, wireplumber,
doas, polkit, acpid, tlp, zsh, neovim, git, alacritty,
**llvm-core/llvm**, **llvm-core/clang**, rEFInd

### Desktop packages (step 7)

niri · waybar · fuzzel · swaylock · swaybg · grim · slurp ·
wl-clipboard · dunst · xdg-desktop-portal-wlr · polkit-gnome ·
pavucontrol · xdg-utils · xdg-user-dirs · nerdfonts (JetBrains Mono) ·
brave-browser-nightly

### User & dotfiles

- Hostname: `mba`
- User: `legend` (wheel, audio, video, input, usb, plugdev, bluetooth)
- Shell: zsh
- Passwords set via `openssl passwd -6` for PAM compatibility
- Dotfiles cloned from `github.com/legendarymsr/legenddots` with symlinks
  for niri, waybar, fuzzel, dunst, swaylock, alacritty, zsh

### doas vs sudo

This install uses `app-admin/doas` (OpenDoas) instead of `app-admin/sudo`.

| | doas | sudo |
|---|---|---|
| Codebase size | ~600 lines | ~fitting plus its plugins; tens of thousands of lines |
| Config | `/etc/doas.conf`, one-line rules | `/etc/sudoers`, its own grammar + `visudo` |
| Attack surface | Minimal — one job, no plugin system | Larger — PAM stack, plugins, logging subsystems |
| CVE history | Rare | Multiple privilege-escalation CVEs over the years (e.g. CVE-2021-3156) |
| Features | Deliberately bare: run a command as another user, optionally `persist` the auth timestamp | Lecture messages, command logging, per-command timeouts, LDAP/SSSD integration, extensive option matrix |

Config here is one line in `/etc/doas.conf`:

```
permit persist legend as root
```

`persist` mirrors sudo's timestamp caching so you're not re-entering
your password every command. doas trades sudo's feature depth for a
much smaller, easier-to-audit codebase — fewer features means fewer
places for a privilege-escalation bug to hide.

If you need sudo's extras (lecture messages, fine-grained logging,
LDAP-backed rules), set `PRIV_ESC=sudo` before running the script —
it installs `app-admin/sudo` instead and grants `wheel` via
`/etc/sudoers.d/wheel` rather than writing `/etc/doas.conf`:

```sh
PRIV_ESC=sudo bash install.sh
```

### Default credentials

| Account | Password      |
|---------|---------------|
| legend  | `legendary`   |
| root    | `legendary123`|

**Change these immediately after first boot:**

```sh
passwd legend
doas passwd root
```

---

## Bootloader

**rEFInd** — GRUB is unreliable on Apple EFI firmware. rEFInd is
Mac-native, auto-detects kernels, and requires no configuration.

```sh
refind-install --usedefault /dev/sda1
```

---

## Kernel — hardware options

| Option                        | Reason                                  |
|-------------------------------|-----------------------------------------|
| `CONFIG_DRM_I915`             | Intel HD 5000 (iris)                    |
| `CONFIG_SND_HDA_CODEC_CIRRUS` | Cirrus Logic CS4208 audio               |
| `CONFIG_HID_APPLE`            | Apple keyboard / trackpad               |
| `CONFIG_BT_HCIBTUSB`         | Broadcom Bluetooth                      |
| `CONFIG_SATA_AHCI`            | Apple PCIe SSD (AHCI)                  |
| `CONFIG_X86_INTEL_PSTATE`     | Haswell HWP power states                |
| `CONFIG_THUNDERBOLT`          | Thunderbolt / USB-C dongles             |
| `CONFIG_USB_XHCI_HCD`         | USB 3.0                                 |
| `CONFIG_USB_EHCI_HCD`         | USB 2.0                                 |

## Kernel — broadcom-sta (`wl`) compatibility

`net-wireless/broadcom-sta` refuses to build (compile failure, not just a
runtime conflict) unless these are set *before* the kernel build, not just
the `/etc/modprobe.d/broadcom-sta.conf` blacklist:

| Option                     | Reason                                          |
|-----------------------------|--------------------------------------------------|
| `CONFIG_PREEMPT_DYNAMIC=n`  | Defaults to "Preemptible Kernel", which pulls in `CONFIG_PREEMPT_RCU` — broadcom-sta hard-refuses to build against it |
| `CONFIG_PREEMPT_NONE=y`     | Preemption model broadcom-sta accepts            |
| `CONFIG_BRCMSMAC=n`, `CONFIG_BRCMFMAC=n`, `CONFIG_B43=n`, `CONFIG_B43LEGACY=n`, `CONFIG_SSB=n`, `CONFIG_MAC80211=n` | In-tree drivers/stack that conflict with `wl`; disabled at the kernel-config level, not just blacklisted at runtime |

Even with the config above, `broadcom-sta` can still fail to compile
against a kernel that's simply too new: it's an unmaintained,
out-of-tree driver, and `ACCEPT_KEYWORDS="~amd64"` (needed for the
overlay packages) also lets `sys-kernel/gentoo-sources` float on the
bleeding-edge testing series, which broadcom-sta's compat patches
haven't caught up to. The script pins just that one emerge call back to
stable with an env var override:

```sh
ACCEPT_KEYWORDS="-~amd64 amd64" emerge sys-kernel/gentoo-sources
```

`ACCEPT_KEYWORDS` is an *incremental* portage variable, same as `USE` —
plain `ACCEPT_KEYWORDS="amd64"` would only add to the `~amd64` inherited
from make.conf rather than replace it, and `~amd64` already implies
"testing is fine", so that would have been a silent no-op (this is
exactly what happened in an earlier version of this fix: it looked
right but kept building the testing kernel anyway). The leading
`-~amd64` explicitly drops the inherited testing acceptance before
adding `amd64` back, so only *this* emerge call is genuinely
stable-only — overlay packages and everything else still use the
global `~amd64`. (A version before *that* tried a `package.mask` entry
of `~sys-kernel/gentoo-sources`, which isn't valid atom syntax either —
the `~` version operator requires an actual version number, it doesn't
mean "all testing-keyword ebuilds of this package"; portage silently
ignored it.) `resume.sh` detects a too-new kernel left over from before
this fix (major version ≥ 7), unmerges it, and forces a rebuild on the
stable kernel automatically.

## Kernel — hardening options

| Option                           | Protection              |
|----------------------------------|-------------------------|
| `CONFIG_RANDOMIZE_BASE`          | KASLR                   |
| `CONFIG_RANDOMIZE_MEMORY`        | Memory ASLR             |
| `CONFIG_PAGE_TABLE_ISOLATION`    | Meltdown (PTI)          |
| `CONFIG_RETPOLINE`               | Spectre v2              |
| `CONFIG_STRICT_KERNEL_RWX`       | No W+X kernel pages     |
| `CONFIG_STRICT_MODULE_RWX`       | No W+X module pages     |
| `CONFIG_SECURITY_LOCKDOWN_LSM`   | Lockdown LSM            |
| `CONFIG_INTEL_MEI=n` (+ variants)| ME kernel interface off |
| `CONFIG_MODULE_SIG_FORCE=n`      | Allows unsigned `wl`    |

---

## WiFi — first boot

The `wl` module is loaded via `/etc/conf.d/modules` and conflicting
in-tree drivers are blacklisted in `/etc/modprobe.d/broadcom-sta.conf`.
NetworkManager handles the connection automatically.

If WiFi doesn't come up:

```sh
doas modprobe wl
nmtui
```

---

## Intel ME

The kernel ME interface is disabled at build time. For firmware-level
neutralisation, `flashrom` + `me_cleaner -S` can be attempted via
software — though on Apple hardware the SPI flash is typically locked
and a hardware programmer (e.g. CH341A) may be required.
