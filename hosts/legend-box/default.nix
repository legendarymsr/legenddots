{ pkgs, ... }:

{
  # ── User ──────────────────────────────────────────────────────────────────────────
  users.users.legend = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" "video" "docker" "wireshark" "libvirt" ];
    shell        = pkgs.zsh;
  };

  # ── Security ───────────────────────────────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = true;
  security.apparmor.enable         = true;
  security.rtkit.enable            = true;

  services.fail2ban.enable   = true;
  networking.firewall.enable = true;
  boot.kernelPackages        = pkgs.linuxPackages_hardened;

  # ── Audio ────────────────────────────────────────────────────────────────────────────
  services.pipewire = {
    enable             = true;
    alsa.enable        = true;
    alsa.support32Bit  = true;
    pulse.enable       = true;
    wireplumber.enable = true;
  };

  # ── Desktop ────────────────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
  };

  programs.zsh.enable = true;

  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # ── Fonts ───────────────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

  system.stateVersion = "25.11";
}
