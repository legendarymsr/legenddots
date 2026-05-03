{ ... }:

{
  imports = [
    ./home/packages.nix
    ./home/nixvim.nix
  ];

  home.username = "legend";
  home.homeDirectory = "/home/legend";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
