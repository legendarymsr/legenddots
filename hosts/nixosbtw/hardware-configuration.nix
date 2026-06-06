{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules          = [];
  boot.kernelModules                 = [ "kvm-intel" ];
  boot.extraModulePackages           = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/9615393f-d189-4252-b088-61a5f3b24413";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/0b9dddc6-0d2d-46a2-8849-f674bc053211"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
