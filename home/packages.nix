{ pkgs, ... }:

{
  home.packages = with pkgs; [
    git tmux htop btop ripgrep fd fzf
    brave

    # Hyprland ecosystem
    hyprpaper hyprlock waybar dunst fuzzel polkit_gnome

    # Wayland utilities
    grim slurp wl-clipboard brightnessctl

    # Audio (wpctl)
    wireplumber pavucontrol

    # Networking
    networkmanagerapplet

    # Terminal & shell prompt
    alacritty starship

    # Security tools
    nmap metasploit burpsuite hashcat john wireshark-qt ghidra sqlmap ffuf
    radare2 bettercap aircrack-ng android-tools
  ];
}
