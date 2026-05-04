# legenddots

Personal dotfiles for NixOS, Guix, and Arch Linux. Theme: **Tokyo Night** throughout.

---

## Browsers

| Config | Browser |
|--------|---------|
| NixOS | `brave` (nixpkgs) |
| Guix | `icecat` (GNU, fully libre) |
| Arch rices | `brave-origin-nightly-bin` (AUR), installed by each `install.sh` |

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

## Manifesto

Your editor should not phone home. Your OS should not require a Microsoft account. Your tools should not need 40GB of RAM to open a text file.

Every package here is auditable. Every config is version controlled. Nothing runs that wasn't explicitly put there.

- Proprietary software is a liability, not a feature.
- If you can't read the source, you don't own the tool.
- Reproducibility is a security property.
- Bloat is attack surface.

The manifesto page lives in `manifesto/` — open `index.html` locally.

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

## Keybinds

Arch rices (niri, i3, hyprland) use `Mod` (Super). Guix/ratpoison uses `C-t` as the prefix key instead.

| Key | Guix `C-t` equivalent | Action |
|-----|-----------------------|--------|
| `Mod+Return` | `C-t c` | Terminal |
| `Mod+d` | `C-t d` | Launcher |
| `Mod+b` | `C-t b` | Browser |
| `Mod+q` | `C-t q` | Close window |
| `Mod+hjkl` | `C-t n/p` | Focus |
| `Mod+Shift+hjkl` | — | Move window |
| `Mod+1-9` | — | Workspaces |
| `Mod+Escape` | — | Lock screen |
| `Mod+Shift+e` | `C-t Q` | Exit |
| `Print` | `C-t Print` | Screenshot |
