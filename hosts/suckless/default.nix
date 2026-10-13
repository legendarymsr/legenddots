{ lib, pkgs, ... }:

# Installable suckless host: dwm (X11, startx on tty1) with st, dmenu, slock,
# dwl, surf built from suckless/<tool>/config.h, plus the suckless home.nix.
#   sudo nixos-rebuild switch --flake .#suckless
# hardware-configuration.nix is a placeholder; `legenddots-install suckless`
# replaces it.

let
  suckless = import ../../suckless/default.nix { inherit pkgs; };
in
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable      = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  networking.hostName              = "legend-suckless";
  networking.networkmanager.enable = true;
  time.timeZone                    = "Europe/Brussels";

  users.users.legend = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" "video" "audio" ];
  };

  services.xserver = {
    enable = true;
    displayManager.startx.enable = true;
    windowManager.dwm = { enable = true; package = suckless.dwm; };
  };
  programs.bash.loginShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ -z "$DISPLAY" ]; then exec startx; fi
  '';
  security.wrappers.slock = {
    source = "${suckless.slock}/bin/slock"; owner = "root"; group = "root"; setuid = true;
  };

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  environment.systemPackages = with pkgs; [ foot wmenu swaylock git ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home-manager.useGlobalPkgs   = true;
  home-manager.useUserPackages = true;
  home-manager.users.legend = {
    imports = [ ../../suckless/home.nix ];
    legend.suckless.enable = true;
    home.file.".xinitrc".text = "exec dwm\n";
    home.stateVersion = "25.11";
  };

  system.stateVersion = "25.11";
}
