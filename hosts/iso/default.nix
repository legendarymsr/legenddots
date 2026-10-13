{ lib, pkgs, ... }:

# Live + installer ISO built from legend-box: same system config (Hyprland,
# PipeWire, hardening, zsh) and the same home-manager setup, minus the
# placeholder hardware/bootloader bits the ISO module provides itself.
# Boots on legacy BIOS (syslinux/isolinux) and UEFI (GRUB); hybrid so it can
# be dd'd to a USB stick.

{
  imports = [ ../legend-box ];

  isoImage.makeBiosBootable = true;
  isoImage.makeEfiBootable  = true;
  isoImage.makeUsbBootable  = true;
  image.baseName            = lib.mkForce "legenddots-nixos";
  isoImage.squashfsCompression = "zstd -Xcompression-level 15";

  # legend-box boots with systemd-boot; the ISO brings its own bootloaders.
  boot.loader.systemd-boot.enable      = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Use the ISO's default kernel so ZFS etc. from the installer base still build.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  # Log in as legend (password "legend") on the live system.
  users.users.legend.initialPassword = "legend";

  # Boot straight into Hyprland as legend: greetd runs it once on tty1 with
  # no prompt; logging out drops to tuigreet. No GNOME / GDM.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = { user = "legend"; command = "Hyprland"; };
      default_session.command =
        "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
    };
  };
  services.getty.autologinUser = lib.mkForce null;

  # The minimal CD enables wpa_supplicant; legend-box uses NetworkManager.
  networking.wireless.enable       = lib.mkForce false;
  networking.networkmanager.enable = true;

  networking.hostName = lib.mkForce "legend-iso";
}
