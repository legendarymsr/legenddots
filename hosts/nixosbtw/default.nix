{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ── User ──────────────────────────────────────────────────────────────────
  users.users.legend = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" "video" ];
    shell        = pkgs.zsh;
    initialPassword = "legend";
  };

  security.sudo.wheelNeedsPassword = true;

  # ── Audio ─────────────────────────────────────────────────────────────────
  services.pipewire = {
    enable             = true;
    alsa.enable        = true;
    alsa.support32Bit  = true;
    pulse.enable       = true;
    wireplumber.enable = true;
  };

  # ── Desktop ───────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
  };

  programs.zsh.enable = true;

  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

  # ── VM guest utils ────────────────────────────────────────────────────────
  services.qemuGuest.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Stockholm";

  system.stateVersion = "25.11";
}
