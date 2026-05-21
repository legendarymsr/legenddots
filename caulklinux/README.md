# CaulkLinux

Minimal Arch-based ISO. Single-file TUI installer written in C — static binary,
raw `termios`, zero ncurses. GPL-2.0.

```
┌─────────────────────────────────────────────────┐
│              CaulkLinux Installer               │
├─────────────────────────────────────────────────┤
│                                                 │
│  Modes:  i3 (X11)  Hyprland (Wayland)  Niri    │
│                                                 │
│  Dotfiles are copied from /dots on the ISO.     │
│                                                 │
│  All data on the selected disk will be erased.  │
└─────────────────────────────────────────────────┘
```

## Install Modes

| Mode     | Display | WM       | Bar     | Launcher | Lock      |
|----------|---------|----------|---------|----------|-----------|
| i3       | X11     | i3-wm    | polybar | rofi     | i3lock    |
| Hyprland | Wayland | hyprland | waybar  | fuzzel   | hyprlock  |
| Niri     | Wayland | niri     | waybar  | fuzzel   | swaylock  |

Each mode installs only its own stack — nothing extra.

## Installer Steps

1. Disk selection
2. Username + password + hostname
3. Timezone + keymap
4. Window manager
5. Confirm → install

UEFI: GPT with 512 MB EFI partition + ext4 root.  
BIOS: MBR with single ext4 root.

## Build

**Requirements** (Arch Linux host):

```sh
sudo pacman -S archiso dosfstools squashfs-tools gcc
```

**Build ISO:**

```sh
git clone https://github.com/legendarymsr/caulklinux
cd caulklinux

# Add your dotfiles
cp -r /path/to/your/dots/* dots/

# Compile installer + build ISO
make iso
# → caulklinux-YYYY.MM-x86_64.iso
```

## Flash & Boot

```sh
dd if=caulklinux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot from USB. The installer launches automatically on root login.

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

## Principles

- No proprietary software
- No commercial services
- No AI tools
- Minimal — only what's needed per WM
- One C file, zero library dependencies beyond libc

## License

[GPL-2.0-only](LICENSE)
