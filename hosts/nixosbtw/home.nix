# SPDX-License-Identifier: GPL-3.0-or-later
{ ... }:

{
  imports = [
    ../../modules/home/packages.nix
    ../../modules/home/shell.nix
    ../../modules/home/nixvim.nix
    ../../modules/home/hyprland.nix
  ];

  home.username      = "legend";
  home.homeDirectory = "/home/legend";
  home.stateVersion  = "25.11";

  programs.home-manager.enable = true;
}
