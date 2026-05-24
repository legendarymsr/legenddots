{ pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    extraConfig = builtins.readFile ../../hyprland/hyprland.conf;
  };

  xdg.configFile = {
    "hypr/hyprlock.conf".source  = ../../hyprland/hyprlock.conf;
    "hypr/hyprpaper.conf".source = ../../hyprland/hyprpaper.conf;
    "waybar/config.jsonc".source = ../../hyprland/waybar/config.jsonc;
    "waybar/style.css".source    = ../../hyprland/waybar/style.css;
    "alacritty/alacritty.toml".source = ../../alacritty.toml;
  };

  # Polkit agent — replaces the hardcoded /usr/lib path in hyprland.conf
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "hyprland-session.target" ];
    wants    = [ "hyprland-session.target" ];
    after    = [ "hyprland-session.target" ];
    serviceConfig = {
      Type           = "simple";
      ExecStart      = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart        = "on-failure";
      RestartSec     = 1;
      TimeoutStopSec = 10;
    };
  };
}
