# legenddots

Personal dotfiles for NixOS, Guix, and Arch Linux. Theme: **Tokyo Night** throughout.

---

## Structure

```
legenddots/
├── flake.nix                  NixOS flake entry
├── system.nix                 NixOS system config (users, security, services, kernel)
├── configuration.nix          NixOS stub
├── home.nix                   Home-manager entry
├── home/
│   ├── packages.nix           Package list
│   └── nixvim.nix             Neovim via NixVim
│
├── config.scm                 Guix system config
├── home-configuration.scm     Guix home config (ratpoison, zsh, emacs, dotfiles)
│
├── init.lua                   Neovim config
├── init.el                    Emacs config
├── alacritty.toml             Terminal (Tokyo Night, 95% opacity)
│
├── niri/                      Niri rice (Wayland)
│   ├── config.kdl
│   ├── waybar/
│   ├── fuzzel/
│   ├── dunst/
│   ├── swaylock/
│   └── install.sh
│
├── i3/                        i3 rice (X11)
│   ├── config
│   ├── picom.conf
│   ├── polybar/
│   ├── rofi/
│   └── install.sh
│
└── hyprland/                  Hyprland rice (Wayland)
    ├── hyprland.conf
    ├── hyprpaper.conf
    ├── hyprlock.conf
    ├── waybar/
    └── install.sh
```

---

## NixOS

```bash
nixos-rebuild switch --flake .#legend-box
```

Home-manager is integrated into the flake. NixVim handles Neovim declaratively.

---

## Guix

```bash
# System
guix system reconfigure config.scm

# Home
guix home reconfigure home-configuration.scm
```

Libre software only. Ratpoison as WM, Emacs as editor, hardened kernel arguments, AppArmor, nftables.

---

## Arch Rice

Each WM has a self-contained install script. Requires `paru` or `yay`.

```bash
# Niri (Wayland, requires waybar-git from AUR)
bash niri/install.sh

# i3 (X11)
bash i3/install.sh

# Hyprland (Wayland)
bash hyprland/install.sh
```

Install scripts symlink configs and back up any existing ones.

---

## Terminal

`alacritty.toml` — Tokyo Night, JetBrainsMono Nerd Font, 95% opacity.

---

## Keybinds (all WMs)

| Key | Action |
|-----|--------|
| `Mod+Return` | Terminal |
| `Mod+d` | Launcher |
| `Mod+hjkl` | Focus |
| `Mod+Shift+hjkl` | Move |
| `Mod+1-9` | Workspaces |
| `Mod+Escape` | Lock screen |
| `Mod+Shift+e` | Exit |
| `Print` | Screenshot |
