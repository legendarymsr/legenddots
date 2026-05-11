{ ... }:

{
  imports = [
    ./home/packages.nix
    ./home/shell.nix
    ./home/nixvim.nix
    ./home/hyprland.nix
  ];

  home.username = "legend";
  home.homeDirectory = "/home/legend";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
