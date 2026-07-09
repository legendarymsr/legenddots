{ config, lib, pkgs, modulesPath, ... }:

# Generated for MacBook Air 6,2 (mid-2013):
#   /dev/sda1  EFI   vfat   ~200 MiB  → /boot
#   /dev/sda2  swap         ~8 GiB
#   /dev/sda3  root  ext4   remainder → /
#
# After running `nixos-generate-config --root /mnt` on the machine, replace
# the fileSystems entries here with the UUID-based ones from the generated
# /mnt/etc/nixos/hardware-configuration.nix.

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Modules needed in early boot (root is ext4 on AHCI SATA)
  boot.initrd.availableKernelModules = [
    "xhci_pci"   # USB 3.0 controller (Haswell)
    "ahci"       # SATA
    "usb_storage"
    "sd_mod"
    "i915"       # Intel HD 5000 — needed early for KMS
  ];
  boot.initrd.kernelModules = [];

  # Broadcom BCM4360 Wi-Fi — wl is the proprietary driver (broadcom-sta).
  # All in-kernel competing drivers must be blacklisted.
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.kernelModules = [ "wl" "kvm-intel" ];
  boot.blacklistedKernelModules = [
    "b43" "b43legacy" "ssb" "bcm43xx"
    "brcm80211" "brcmfmac" "brcmsmac" "bcma"
  ];

  # ── Disk layout ────────────────────────────────────────────────────────────
  fileSystems."/" = {
    device = "/dev/sda3";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/sda1";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ { device = "/dev/sda2"; } ];

  # ── Platform ───────────────────────────────────────────────────────────────
  nixpkgs.hostPlatform                = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode  = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
