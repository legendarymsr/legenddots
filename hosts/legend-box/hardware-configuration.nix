{ config, lib, pkgs, modulesPath, ... }:

# PLACEHOLDER — replace this entire file with the one generated on the
# real machine: run `nixos-generate-config --root /mnt` during install,
# then copy /mnt/etc/nixos/hardware-configuration.nix here.

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules          = [];
  boot.kernelModules                 = [ "kvm-intel" ];
  boot.extraModulePackages           = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
