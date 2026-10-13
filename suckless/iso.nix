{ lib, pkgs, ... }:

# Live ISO for the suckless setup: every tool from ./default.nix built with our
# config.h (st, slock, dmenu, dwm, dwl, surf) + the home.nix dotfiles.
# Autologins legend on tty1 straight into dwm (X11); dwl is there too.
# Hybrid: syslinux for legacy BIOS, GRUB for UEFI.
# Build: nix build .#suckless-iso   (from the repo root flake)

let
  suckless = import ./default.nix { inherit pkgs; };
in
{
  isoImage.makeBiosBootable    = true;
  isoImage.makeEfiBootable     = true;
  isoImage.makeUsbBootable     = true;
  isoImage.squashfsCompression = "zstd -Xcompression-level 15";
  image.baseName               = lib.mkForce "legenddots-suckless-nixos";
  networking.hostName          = "legend-suckless";

  users.users.legend = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "video" "audio" ];
    initialPassword = "legend";
  };
  services.getty.autologinUser = lib.mkForce "legend";

  # X11 + dwm via startx; tty1 login execs it.
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

  home-manager.useGlobalPkgs   = true;
  home-manager.useUserPackages = true;
  home-manager.users.legend = {
    imports = [ ./home.nix ];
    legend.suckless.enable = true;
    home.file.".xinitrc".text = "exec dwm\n";
    home.stateVersion = "25.11";
  };

  system.stateVersion = "25.11";
}
