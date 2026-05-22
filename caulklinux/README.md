# CaulkLinux

Minimal Arch-based ISO. Single-file TUI installer written in C — static binary,
raw `termios`, zero ncurses. GPL-2.0.

---

## Install Modes

### i3 — X11 tiling

The classic X11 stack. Fast, keyboard-driven, works on any hardware including
machines without Wayland support.

| Component    | Package             |
|--------------|---------------------|
| WM           | i3-wm               |
| Bar          | polybar             |
| Launcher     | rofi                |
| Locker       | i3lock              |
| Compositor   | picom               |
| Notifications| dunst               |
| Login        | lightdm             |

---

### Hyprland — Wayland compositor

Eye candy and animations with full Wayland. Requires a GPU with good Mesa/DRM
support (most modern AMD/Intel; Nvidia works with proprietary drivers).

| Component    | Package                         |
|--------------|---------------------------------|
| Compositor   | hyprland                        |
| Bar          | waybar                          |
| Launcher     | fuzzel                          |
| Locker       | hyprlock                        |
| Notifications| dunst                           |
| Portals      | xdg-desktop-portal-hyprland     |

---

### Niri — Wayland scrolling WM

Infinite scrolling canvas of windows. Wayland-native, wlroots-based. Suits
ultrawide or multi-monitor setups.

| Component    | Package                      |
|--------------|------------------------------|
| WM           | niri                         |
| Bar          | waybar                       |
| Launcher     | fuzzel                       |
| Locker       | swaylock                     |
| Notifications| dunst                        |
| Portals      | xdg-desktop-portal-gnome     |

---

### Custom — Nerd mode

Skip the presets. A scrollable checkbox list lets you hand-pick every package
before install. ~45 options across WMs, bars, launchers, terminals, editors,
browsers, media tools, audio, and fonts. Dotfiles are copied for any WM you
selected.

---

## Installer Walkthrough

### 1 — Welcome

```
  ╔══════════════════════════════════════════════════════════╗
  ║                  CaulkLinux Installer                    ║
  ╠══════════════════════════════════════════════════════════╣

  Minimal Arch-based Linux

  Modes:  i3   Hyprland   Niri   Custom

  Dotfiles are copied from /dots on the ISO.

  All data on the selected disk will be erased.

  ╚══════════════════════════════════════════════════════════╝
  Press Enter to begin...
```

---

### 2 — Disk selection

All block devices are discovered from `/sys/block`. Loop, RAM, and optical
drives are filtered out automatically.

```
  ╔══════════════════════════════════════════════════════════╗
  ║                Select Installation Disk                  ║
  ╠══════════════════════════════════════════════════════════╣

  ▌ /dev/nvme0n1                                            ▐
    /dev/sda
    /dev/sdb

  [j/↓] down  [k/↑] up  [Enter] select

  ╚══════════════════════════════════════════════════════════╝
  Selected: /dev/nvme0n1  (UEFI)
```

UEFI is detected from `/sys/firmware/efi`. The partition layout is chosen
automatically:

- **UEFI** → GPT, 512 MB FAT32 EFI partition + ext4 root
- **BIOS** → MBR, single ext4 root with boot flag

---

### 3 — User setup

```
  ╔══════════════════════════════════════════════════════════╗
  ║                       User Setup                         ║
  ╠══════════════════════════════════════════════════════════╣

  Username: legend
  Password: ········
  Confirm : ········
  Hostname: arch-box

  ╚══════════════════════════════════════════════════════════╝
```

Password is typed hidden. A mismatch loops back to retry.

---

### 4 — Locale

```
  ╔══════════════════════════════════════════════════════════╗
  ║                         Locale                           ║
  ╠══════════════════════════════════════════════════════════╣

  Timezone (e.g. Europe/Brussels): Europe/Brussels
  Keymap   (e.g. se, us, de):      se

  ╚══════════════════════════════════════════════════════════╝
```

Defaults to `Europe/Brussels` / `se` if left empty.

---

### 5 — Window manager

```
  ╔══════════════════════════════════════════════════════════╗
  ║                     Window Manager                       ║
  ╠══════════════════════════════════════════════════════════╣

    i3        — X11 · i3-wm · polybar · rofi · i3lock
  ▌ Hyprland  — Wayland · hyprland · waybar · fuzzel · hyprlock ▐
    Niri      — Wayland · niri · waybar · fuzzel · swaylock
    Custom    — pick your own packages (nerd mode)

  [j/↓] down  [k/↑] up  [Enter] select

  ╚══════════════════════════════════════════════════════════╝
```

Choosing **Custom** opens the package picker on the next screen.

---

### 6 — Custom package picker *(nerd mode only)*

Space toggles a package. Enter confirms and proceeds to the confirm screen.

```
  ╔══════════════════════════════════════════════════════════╗
  ║                    Custom Packages                       ║
  ╠══════════════════════════════════════════════════════════╣
  [j/k] move   [Space] toggle   [Enter] confirm

    [x] alacritty             Alacritty (GPU terminal)
  ▌ [x] hyprland              Hyprland compositor (Wayland)  ▐
    [ ] hyprlock               Hyprlock (Hyprland locker)
    [ ] i3-wm                  i3 tiling WM (X11)
    [ ] kitty                  Kitty (GPU terminal)
    [x] neovim                 Neovim
    [x] pipewire               PipeWire audio server
    [x] pipewire-alsa          PipeWire ALSA compat
    [x] pipewire-pulse         PipeWire PulseAudio compat
    [ ] rofi                   Rofi launcher (X11/Wayland)

  ╚══════════════════════════════════════════════════════════╝
  6 selected   1/46 shown
```

Categories available: window managers, bars, launchers, terminals, lockers,
notifications, compositors, browsers, editors, file managers, media, screenshot
tools, clipboard, audio, portals, polkit, fonts.

---

### 7 — Confirm

```
  ╔══════════════════════════════════════════════════════════╗
  ║                  Confirm Installation                    ║
  ╠══════════════════════════════════════════════════════════╣

  Disk     : /dev/nvme0n1
  Firmware : UEFI
  User     : legend
  Hostname : arch-box
  Timezone : Europe/Brussels
  Keymap   : se
  WM       : Hyprland

  ALL DATA ON /dev/nvme0n1 WILL BE ERASED.

  ▌ Install now                                             ▐
    Abort

  ╚══════════════════════════════════════════════════════════╝
```

---

### 8 — Installation

```
  ╔══════════════════════════════════════════════════════════╗
  ║                  Installing CaulkLinux                   ║
  ╠══════════════════════════════════════════════════════════╣

  → Partitioning /dev/nvme0n1 ...
  → Mounting ...
  → Installing packages ...
  → Configuring system ...
  → Copying dotfiles ...
  → Unmounting ...

  Installation complete!
  Log: /tmp/caulk-install.log

  Remove the USB and reboot.

  Press Enter to reboot...

  ╚══════════════════════════════════════════════════════════╝
```

Full log is written to `/tmp/caulk-install.log` on the live system.

---

## Build

**Requirements** (Arch Linux host):

```sh
sudo pacman -S archiso dosfstools squashfs-tools gcc
```

**Build ISO:**

```sh
cd legenddots/caulklinux
make iso
# → caulklinux-YYYY.MM-x86_64.iso
```

Remove old builds before rebuilding:

```sh
make clean
```

---

## Flash & Boot

```sh
dd if=caulklinux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot from USB. The installer launches automatically on root login.

---

## Dotfiles Layout

Place your dotfiles in `dots/` before building the ISO.
The installer copies them to `~/.config/` on the target system.

```
dots/
├── i3/             → ~/.config/i3/          (i3 mode)
├── hyprland/       → ~/.config/hyprland/    (Hyprland mode)
├── niri/           → ~/.config/niri/        (Niri mode)
├── alacritty/      → ~/.config/alacritty/
├── waybar/         → ~/.config/waybar/
├── dunst/          → ~/.config/dunst/
├── nvim/           → ~/.config/nvim/
└── .zshrc          → ~/
```

Custom mode copies dotfiles for every WM you selected.

---

## Source

```
caulklinux/
├── installer/install.c   # TUI installer — single C99 file
├── iso/                  # archiso profile
│   ├── profiledef.sh
│   ├── packages.x86_64   # live environment packages
│   ├── pacman.conf
│   └── airootfs/         # files overlaid onto the live system
├── dots/                 # populate before building
└── Makefile
```

---

## Principles

- No proprietary software
- No commercial services
- No AI tools
- Minimal — only what's needed per WM
- One C file, zero library dependencies beyond libc

---

## License

[GPL-2.0-only](LICENSE)
