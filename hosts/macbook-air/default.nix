{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Boot ───────────────────────────────────────────────────────────────────
  # rEFInd plays nicer with Apple EFI than systemd-boot.
  # canTouchEfiVariables must be false — writing to Apple NVRAM can brick it.
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint    = "/boot";
  boot.loader.refind.enable           = true;

  # Apple-specific quirks: acpi_osi= prevents ACPI namespace conflicts with
  # OS X tables; pcie_aspm=off works around PCIe power-management hangs on
  # Apple EFI firmware.
  boot.kernelParams = [ "acpi_osi=" "pcie_aspm=off" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Apple keyboard: make F-keys work as real function keys by default
  # (fn + Fx gives media/brightness action).
  boot.extraModprobeConfig = "options hid_apple fnmode=2";

  # ── Nix settings ───────────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Broadcom wl driver is unfree
  nixpkgs.config.allowUnfree = true;

  # ── Networking ─────────────────────────────────────────────────────────────
  networking.hostName              = "macbook-air";
  networking.networkmanager.enable = true;

  # ── User ───────────────────────────────────────────────────────────────────
  users.users.legend = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "networkmanager" "video" "audio" "input" ];
    shell           = pkgs.zsh;
    initialPassword = "legend";
  };

  # ── Security ───────────────────────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = true;
  security.apparmor.enable         = true;
  security.rtkit.enable            = true;

  services.fail2ban.enable   = true;
  networking.firewall.enable = true;

  # ── Graphics ───────────────────────────────────────────────────────────────
  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
  };

  # ── Audio ──────────────────────────────────────────────────────────────────
  # Cirrus CS4208 is supported by the generic HDA driver; pipewire picks it up.
  services.pipewire = {
    enable             = true;
    alsa.enable        = true;
    alsa.support32Bit  = true;
    pulse.enable       = true;
    wireplumber.enable = true;
  };

  # ── Desktop ────────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
  };

  programs.zsh.enable = true;

  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # ── Fonts ──────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

  # ── Locale / time ──────────────────────────────────────────────────────────
  time.timeZone = "Europe/Brussels";

  system.stateVersion = "25.11";
}
