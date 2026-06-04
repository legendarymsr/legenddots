# Gentoo Install Script — MacBook Air 6,2

If you're still on Windows: an OS that phones home by default, forces
updates at 3am, ships a keylogger called "Recall", sells your telemetry
to advertisers, and locks you into a walled garden owned by a company
that tried to embrace-extend-extinguish Linux for 20 years — close this
tab, uninstall it, and come back when you're serious.

If you're on a binary distro clicking "install" on precompiled blobs
you didn't ask for, built by people you don't know, with USE flags you
never chose — you can do better.

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

The script runs fully unattended. A full build takes roughly **4 hours**
on this hardware:

| Phase | Time |
|-------|------|
| Kernel | ~45 min |
| LLVM + clang (O1) | ~1.5 hrs |
| mesa (O1) | ~20 min |
| Desktop packages | ~45 min |
| Everything else | ~30 min |

LLVM, clang, and mesa build with `-O1` to cut compile time roughly in
half. ccache means any subsequent reinstall is significantly faster.

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
MAKEOPTS="-j4"
VIDEO_CARDS="intel iris"
LLVM_TARGETS="X86"
USE="udev elogind dbus wayland alsa -systemd -gnome -kde -qt5 -cups -pulseaudio"
FEATURES="ccache"
ACCEPT_KEYWORDS="~amd64"
```

### Overlays

| Overlay                | Provides                         |
|------------------------|----------------------------------|
| guru                   | niri · nerdfonts · misc apps     |
| hyproverlay            | xdg-desktop-portal-wlr           |
| another-brave-overlay  | brave-browser-nightly            |

### Base packages (step 6)

NetworkManager, bluez, broadcom-sta, elogind, pipewire, wireplumber,
sudo, polkit, acpid, tlp, zsh, neovim, git, alacritty,
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

### Default credentials

| Account | Password      |
|---------|---------------|
| legend  | `legendary`   |
| root    | `legendary123`|

**Change these immediately after first boot:**

```sh
passwd legend
sudo passwd root
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
sudo modprobe wl
nmtui
```

---

## Intel ME

The kernel ME interface is disabled at build time. For firmware-level
neutralisation, `flashrom` + `me_cleaner -S` can be attempted via
software — though on Apple hardware the SPI flash is typically locked
and a hardware programmer (e.g. CH341A) may be required.
