{ lib, pkgs, ... }:

# Lightweight live ISO for the main setup: Hyprland with the repo's
# hyprland.lua / waybar / hyprpaper (modules/home/hyprland.nix), alacritty,
# fuzzel, dunst. The full legend-box (Brave Origin, pentest tools, libvirt,
# nixvim, …) is installed from git + the binary cache by `legenddots-install`.
# Hybrid: syslinux (legacy BIOS) + GRUB (UEFI).

{
  imports = [ ../../modules/nixos/legenddots-install.nix ];

  isoImage.makeBiosBootable    = true;
  isoImage.makeEfiBootable     = true;
  isoImage.makeUsbBootable     = true;
  isoImage.squashfsCompression = "zstd -Xcompression-level 19";
  image.baseName               = lib.mkForce "legenddots-nixos";
  networking.hostName          = "legend-iso";

  documentation.enable = lib.mkForce false;
  # Keep the image small: no speech synth (mbrola/flite), no nixpkgs channel
  # copy (the installer uses the flake), firmware stays.
  services.speechd.enable        = lib.mkForce false;
  system.installer.channel.enable = false;
  documentation.nixos.enable = lib.mkForce false;

  users.users.legend = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "networkmanager" "video" ];
    initialPassword = "legend";
  };
  security.sudo.wheelNeedsPassword = false;

  programs.hyprland.enable = true;
  services.pipewire = { enable = true; pulse.enable = true; };
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Boot straight into Hyprland (via its start-hyprland wrapper) as legend.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = { user = "legend"; command = "start-hyprland"; };
      default_session.command =
        "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd start-hyprland";
    };
  };
  services.getty.autologinUser = lib.mkForce null;

  networking.wireless.enable       = lib.mkForce false;
  networking.networkmanager.enable = true;

  home-manager.useGlobalPkgs   = true;
  home-manager.useUserPackages = true;
  home-manager.users.legend = {
    imports = [ ../../modules/home/hyprland.nix ];
    home.packages = with pkgs; [
      alacritty fuzzel dunst hyprpaper hyprlock waybar
      grim slurp wl-clipboard brightnessctl lynx
      # Live-only: hyprland.lua's Super+B runs `brave-origin-nightly`; on the
      # ISO that opens lynx in alacritty (installed legend-box gets Brave Origin).
      (writeShellScriptBin "brave-origin-nightly" ''
        exec alacritty -e lynx "''${@:-https://lite.duckduckgo.com/lite/}"
      '')
    ];
    home.stateVersion = "25.11";
  };

  system.stateVersion = "25.11";
}
