# Gentoo Install Script — MacBook Air 6,2

Fully automated Gentoo installation script targeting the **MacBook Air 6,2
(Mid 2013, 1.3 GHz Intel Core i5-4250U)**. One script, zero hand-holding.
Asks a few questions, then builds the whole system unattended.

Hardened kernel, OpenRC, btrfs or ext4, your choice of desktop.

---

## Target Hardware

| Component     | Detail                                          |
|---------------|-------------------------------------------------|
| CPU           | Intel Core i5-4250U (Haswell, 2C/4T, 1.3 GHz) |
| iGPU          | Intel HD Graphics 5000 (Iris, GT3)              |
| WiFi          | Broadcom BCM4360 (proprietary `wl` driver)      |
| Audio         | Cirrus Logic CS4208 (Intel HDA)                 |
| Storage       | Apple PCIe SSD (AHCI, `/dev/sda`)               |
| Firmware      | UEFI only                                       |

---

## Before You Start

The BCM4360 chip has no open-source driver and no support in the Gentoo live
ISO. You need an internet connection to run the script.

**Recommended setup:**
1. Boot the Gentoo **LiveGUI** ISO (has a browser + terminal)
2. Tether your phone via USB (instant internet, no WiFi needed)
3. SSH in from your phone with KDE Connect or just work directly in the terminal
4. Run the script inside `tmux` so a disconnect doesn't kill the build

```sh
pacman -S tmux   # on arch live
# or just use the terminal app in the LiveGUI
tmux new -s install
bash install.sh
```

---

## Walkthrough

### 1 — Hardware check

The script reads DMI to verify it's running on a MacBook Air 6,x. If the
board doesn't match it warns you and asks whether to continue.

```
── Hardware check
:: DMI product: MacBookAir6,2
:: Broadcom WiFi detected: Broadcom Inc. BCM4360 802.11ac
```

---

### 2 — Disk

All block devices are listed. Type the name without `/dev/`.

```
── Configuration

NAME   SIZE  MODEL
sda    128G  APPLE SSD SD0128F

?    Target disk (e.g. sda):
> sda
```

---

### 3 — Filesystem

```
?    Root filesystem — ext4 or btrfs? [ext4]:
> btrfs
```

btrfs gets three subvolumes: `@` `/`, `@home` `/home`, `@snapshots` `/.snapshots`,
all mounted with `compress=zstd`. ext4 gets a single partition.

---

### 4 — Swap

```
?    Swap size in GiB (0 to skip, recommended 8 for 8GB RAM):
> 8
```

Set to `0` to skip. The MBA 6,2 shipped with 4 or 8 GB RAM — 8 GiB swap is
recommended if you want hibernate.

---

### 5 — System details

```
?    Hostname [mba]:
> yuki

?    Username:
> legend

?    Timezone (e.g. Europe/Stockholm) [UTC]:
> Europe/Stockholm
```

---

### 6 — Desktop

```
  Desktop environment:
  1) None (TTY only)
  2) Hyprland (Wayland)
  3) niri   (Wayland)
  4) i3     (X11)

?    Choice [1]:
> 2
```

| Choice    | Stack                                                               |
|-----------|---------------------------------------------------------------------|
| None      | Base system only, TTY login                                         |
| Hyprland  | hyprland · waybar · fuzzel · hyprlock · dunst · grim · slurp       |
| niri      | niri · waybar · fuzzel · swaylock · dunst                          |
| i3        | i3 · polybar · rofi · picom · i3lock · xss-lock · maim · xclip    |

All DE choices also install: alacritty · pipewire · pavucontrol ·
brightnessctl · polkit · JetBrains Mono Nerd Font · Brave (nightly).

---

### 7 — Dotfiles

```
?    Clone legenddots dotfiles for the new user? (y/N):
> y
```

Clones `github.com/legendarymsr/legenddots` into `~/legenddots` and symlinks
the right configs for whichever DE you chose. Also creates `~/Pictures/Screenshots`.

---

### 8 — Confirm

```
── Summary
  Disk      : /dev/sda  ← WILL BE ERASED
  Filesystem: btrfs
  Swap      : 8GiB
  Hostname  : yuki
  User      : legend
  Timezone  : Europe/Stockholm
  Desktop   : 2

warn ALL DATA ON /dev/sda WILL BE DESTROYED. Type 'yes' to continue.
> yes
```

Type `yes` exactly. Anything else aborts.

---

### 9 — Unattended build

Everything from here runs without input until the two password prompts at the
end. A kernel build on 4 threads takes roughly 45–90 minutes depending on how
warm the MBA gets.

```
── Partitioning /dev/sda
ok   Partitioned.

── Formatting
ok   Formatted.

── Mounting
ok   Mounted.

── Downloading stage3
:: Fetching: https://mirror.init7.net/gentoo/releases/amd64/autobuilds/...
ok   Stage3 extracted.

── Configuring make.conf
ok   make.conf written.

── Generating fstab
ok   fstab written.

── Entering chroot

:: Syncing portage tree...
:: Setting profile default/linux/amd64/23.0
ok   Timezone set.
ok   Locale set.

── Kernel build
:: Emerging sys-kernel/hardened-sources ...
:: Configuring hardware-specific options ...
:: make -j4 -l3.5 ...          [~45–90 min]
ok   Kernel built and installed.

:: guru overlay ready.
:: gentoo-zh overlay ready.
:: hyproverlay ready.           [Hyprland only]

ok   Base packages installed.
ok   Desktop environment installed.
ok   GRUB installed.

Set password for legend:
Set root password:

ok   Users created.
ok   Dotfiles linked.

Installation complete.
Exit the chroot, unmount, and reboot:
  exit
  umount -R /mnt/gentoo
  reboot
```

---

## Kernel

Built from **sys-kernel/hardened-sources** (linux-hardened patchset on top of
stable). The config is generated with `make defconfig` then tuned for the
exact MBA 6,2 hardware via `scripts/config`, then finalised with
`make olddefconfig`.

### Hardware-specific options

| Option                        | Reason                                           |
|-------------------------------|--------------------------------------------------|
| `CONFIG_DRM_I915`             | Intel HD 5000 (Iris GT3)                        |
| `CONFIG_SND_HDA_CODEC_CIRRUS` | Cirrus Logic CS4208 audio codec                 |
| `CONFIG_HID_APPLE`            | Apple keyboard / trackpad                       |
| `CONFIG_BT_HCIBTUSB`          | Broadcom Bluetooth (USB)                        |
| `CONFIG_SATA_AHCI`            | Apple PCIe SSD (presents as AHCI)              |
| `CONFIG_X86_INTEL_PSTATE`     | HWP power states on Haswell                     |
| `CONFIG_THUNDERBOLT`          | Thunderbolt port (USB-C dongles)                |

AMD/Nvidia/Nouveau DRM drivers are explicitly disabled to keep the image lean.

### Intel ME — kernel-level disable

```
CONFIG_INTEL_MEI     =n
CONFIG_INTEL_MEI_ME  =n
CONFIG_INTEL_MEI_TXE =n
CONFIG_INTEL_MEI_HDCP=n
CONFIG_INTEL_MEI_PXP =n
```

This removes the kernel's Management Engine interface. For full neutralisation
at the firmware level, run `me_cleaner` on the SPI flash separately after the
OS is installed — that's outside the scope of this script.

### Hardened security options

| Option                           | Protection                        |
|----------------------------------|-----------------------------------|
| `CONFIG_RANDOMIZE_BASE`          | KASLR                             |
| `CONFIG_RANDOMIZE_MEMORY`        | Heap/stack ASLR                   |
| `CONFIG_PAGE_TABLE_ISOLATION`    | Meltdown (PTI)                    |
| `CONFIG_RETPOLINE` / `CONFIG_MITIGATION_RETPOLINE` | Spectre v2   |
| `CONFIG_STRICT_KERNEL_RWX`       | No W+X kernel pages               |
| `CONFIG_STRICT_MODULE_RWX`       | No W+X module pages               |
| `CONFIG_SECURITY_LOCKDOWN_LSM`   | Lockdown LSM                      |
| `CONFIG_MODULE_SIG_FORCE=n`      | Off — broadcom-sta `wl` is unsigned|

---

## Packages

### make.conf highlights

```
COMMON_FLAGS="-march=haswell -O2 -pipe"
CPU_FLAGS_X86="aes avx avx2 bmi bmi2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
MAKEOPTS="-j4"
VIDEO_CARDS="intel iris"
USE="bluetooth pipewire -pulseaudio alsa wireless udev policykit \
     X wayland elogind dbus networkmanager \
     -systemd -gnome -kde -qt5 -cups"
```

`iris` (not `i965`) — the `i965` Mesa Gallium driver was removed in Mesa 23+.
Haswell uses the `iris` driver.

### Overlays

| Overlay      | Provides                                        |
|--------------|-------------------------------------------------|
| guru         | nerdfonts · brightnessctl · hyprland · niri    |
| hyproverlay  | xdg-desktop-portal-hyprland (Hyprland only)    |
| gentoo-zh    | brave-bin                                       |

### Base system (always installed)

```
sys-apps/pciutils          sys-apps/usbutils
net-misc/networkmanager    net-wireless/wpa_supplicant
net-wireless/broadcom-sta  net-wireless/bluez
app-admin/sudo             sys-apps/dbus
sys-auth/polkit            sys-apps/acpi
sys-power/acpid            sys-power/tlp
sys-apps/lm-sensors        app-misc/fastfetch
app-shells/zsh             dev-vcs/git
app-editors/neovim         media-video/pipewire
media-video/wireplumber    x11-terms/alacritty
```

---

## WiFi — first boot

The `wl` module is blacklisted against `brcmfmac`, `brcmsmac`, `b43`, and
`bcma`. It loads automatically via `/etc/conf.d/modules`. NetworkManager
manages the connection.

If WiFi doesn't come up on first boot:

```sh
sudo modprobe wl
nmtui
```

---

## Post-install

After rebooting into the new system, run `cpu_flags_x86` to double-check the
CPU flags match what's in `make.conf`:

```sh
emerge app-portage/cpuid2cpuflags
cpuid2cpuflags
```

For full Intel ME firmware neutralisation:

```sh
emerge sys-apps/me-cleaner
# follow me_cleaner docs for your specific SPI flash chip
```
