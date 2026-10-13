{ lib, pkgs, ... }:

# Lightweight suckless live ISO: dwm + st, dmenu, slock (our config.h),
# autologin on tty1 -> startx -> dwm. The full suckless host (dwl, surf, …)
# installs with `sudo legenddots-install suckless /dev/sdX`.
# Hybrid: syslinux (legacy BIOS) + GRUB (UEFI).
# Build: nix build .#suckless-iso   (from the repo root flake)

let
  suckless = import ./default.nix { inherit pkgs; };
in
{
  imports = [ ../modules/nixos/legenddots-install.nix ];

  isoImage.makeBiosBootable    = true;
  isoImage.makeEfiBootable     = true;
  isoImage.makeUsbBootable     = true;
  isoImage.squashfsCompression = "zstd -Xcompression-level 19";
  image.baseName               = lib.mkForce "legenddots-suckless-nixos";
  networking.hostName          = "legend-suckless";
  documentation.enable         = lib.mkForce false;
  # Keep the image small: no speech synth (mbrola/flite), no nixpkgs channel
  # copy (the installer uses the flake), firmware stays.
  services.speechd.enable        = lib.mkForce false;
  system.installer.channel.enable = false;
  documentation.nixos.enable   = lib.mkForce false;

  users.users.legend = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "video" "audio" ];
    initialPassword = "legend";
  };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = lib.mkForce "legend";

  services.xserver = {
    enable = true;
    displayManager.startx.enable = true;
    windowManager.dwm = { enable = true; package = suckless.dwm; };
  };
  programs.bash.loginShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ -z "$DISPLAY" ]; then
      [ -f ~/.xinitrc ] || echo 'exec dwm' > ~/.xinitrc
      exec startx
    fi
  '';
  security.wrappers.slock = {
    source = "${suckless.slock}/bin/slock"; owner = "root"; group = "root"; setuid = true;
  };

  fonts.packages = [ pkgs.dejavu_fonts ];
  environment.systemPackages = [ suckless.st suckless.dmenu ];

  system.stateVersion = "25.11";
}
