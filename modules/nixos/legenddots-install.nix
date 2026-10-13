{ pkgs, ... }:

# `legenddots-install` — live-ISO installer. Everything heavy (Brave Origin,
# pentest tools, libvirt, nixvim, …) is fetched from the binary cache / git at
# install time instead of living on the ISO.
#
#   sudo legenddots-install legend-box /dev/sdX   # wipe sdX, partition, install
#   sudo legenddots-install suckless              # you've already mounted /mnt
#
# Hosts: legend-box (Hyprland, main), suckless (dwm), nixosbtw.
# UEFI: GPT, ESP (label ESP) + root (label nixos), systemd-boot.
# Legacy BIOS: GPT, bios_grub + root, GRUB on the disk.

let
  installer = pkgs.writeShellApplication {
    name = "legenddots-install";
    runtimeInputs = with pkgs; [ git parted dosfstools e2fsprogs util-linux nixos-install-tools nix coreutils gnused ];
    text = ''
      host="''${1:-}"; disk="''${2:-}"
      repo="''${LEGENDDOTS_REPO:-https://github.com/legendarymsr/legenddots}"
      if [ -z "$host" ]; then
        echo "usage: legenddots-install <legend-box|suckless|nixosbtw> [/dev/disk]"
        echo "  with a disk: WIPES it, partitions and mounts at /mnt"
        echo "  without: mount your root at /mnt (and an ESP at /mnt/boot on UEFI) first"
        exit 1
      fi
      [ "$(id -u)" = 0 ] || { echo "run as root (sudo)"; exit 1; }
      efi=0; [ -d /sys/firmware/efi ] && efi=1

      part() { case "$1" in *[0-9]) echo "''${1}p$2" ;; *) echo "$1$2" ;; esac; }

      if [ -n "$disk" ]; then
        printf 'This ERASES %s. Type yes: ' "$disk"; read -r ok
        [ "$ok" = yes ] || exit 1
        umount -R /mnt 2>/dev/null || true
        parted -s "$disk" mklabel gpt
        if [ "$efi" = 1 ]; then
          parted -s "$disk" mkpart ESP fat32 1MiB 513MiB set 1 esp on
        else
          parted -s "$disk" mkpart bios 1MiB 2MiB set 1 bios_grub on
        fi
        parted -s "$disk" mkpart nixos ext4 "$([ "$efi" = 1 ] && echo 513MiB || echo 2MiB)" 100%
        udevadm settle
        mkfs.ext4 -F -L nixos "$(part "$disk" 2)"
        mount /dev/disk/by-label/nixos /mnt
        if [ "$efi" = 1 ]; then
          mkfs.fat -F 32 -n ESP "$(part "$disk" 1)"
          mkdir -p /mnt/boot; mount -o umask=077 "$(part "$disk" 1)" /mnt/boot
        fi
      fi
      mountpoint -q /mnt || { echo "/mnt is not mounted"; exit 1; }

      dest=/mnt/etc/nixos/legenddots
      mkdir -p /mnt/etc/nixos
      [ -d "$dest/.git" ] || git clone "$repo" "$dest"
      hw="$dest/hosts/$host"
      [ -d "$hw" ] || { echo "no such host: $host"; exit 1; }

      nixos-generate-config --root /mnt --show-hardware-config > "$hw/hardware-generated.nix"
      {
        echo '{ lib, ... }: {'
        echo '  imports = [ ./hardware-generated.nix ];'
        if [ "$efi" = 0 ]; then
          bootdisk="$disk"
          [ -n "$bootdisk" ] || bootdisk="/dev/$(lsblk -no pkname "$(findmnt -no SOURCE /mnt)")"
          echo '  boot.loader.systemd-boot.enable = lib.mkForce false;'
          echo '  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;'
          echo "  boot.loader.grub = { enable = true; device = lib.mkForce \"$bootdisk\"; };"
        fi
        echo '}'
      } > "$hw/hardware-configuration.nix"
      git -C "$dest" add -A   # flakes only see tracked files

      nixos-install --flake "$dest#$host" --no-root-passwd \
        --option experimental-features 'nix-command flakes'
      echo "Set a password for legend:"
      nixos-enter --root /mnt -c 'passwd legend'
      echo "Done. Config lives in /etc/nixos/legenddots; reboot."
    '';
  };
in
{
  environment.systemPackages = [ installer pkgs.git ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
