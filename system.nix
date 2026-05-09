{ pkgs, ... }:

{
  users.users.legend = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "docker" "wireshark" "libvirt" ];
    shell = pkgs.zsh;
  };

  security.sudo.wheelNeedsPassword = true;
  security.apparmor.enable = true;
  security.rtkit.enable = true;

  services.fail2ban.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  networking.firewall.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_hardened;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.zsh.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
