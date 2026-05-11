{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Core utilities
    git tmux htop btop ripgrep fd fzf

    # Browser
    brave

    # Terminal
    alacritty

    # Hyprland stack
    hyprpaper hyprlock waybar dunst fuzzel polkit_gnome

    # Wayland utilities
    grim slurp wl-clipboard brightnessctl

    # Audio
    wireplumber pavucontrol

    # Networking
    networkmanagerapplet

    # Security — always-on recon & analysis
    # (heavy pentest tools: nix develop .#pentest)
    nmap john wireshark-qt sqlmap ffuf
    radare2 bettercap aircrack-ng android-tools
  ];
}
