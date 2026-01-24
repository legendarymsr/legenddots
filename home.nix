{ config, pkgs, ... }:

{
  home.username = "legend";
  home.homeDirectory = "/home/legend";
  home.stateVersion = "23.11"; # Read the docs before changing this

  # Packages for a Red Teamer / Neovim Snob
  home.packages = with pkgs; [
    # The Essentials
    neovim
    git
    tmux
    htop
    btop
    ripgrep
    fd
    
    # Red Team / Cybersec Kit
    nmap
    metasploit
    burpsuite
    hashcat
    john
    wireshark-qt
    ghidra-bin
    sqlmap
    ffuf
  ];

  # Neovim snobbery starts here
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}