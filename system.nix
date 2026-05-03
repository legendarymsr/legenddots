{ pkgs, ... }:

{
  users.users.legend = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "docker" "wireshark" "libvirt" ];
    shell = pkgs.zsh;
  };

  security.sudo.wheelNeedsPassword = true;
  security.apparmor.enable = true;

  services.fail2ban.enable = true;

  networking.firewall.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_hardened;
}
