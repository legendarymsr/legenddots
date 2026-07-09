{ pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable      = true;
    xwayland.enable = true;
    configType  = "hyprlang";
    extraConfig = ''
      exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    '' + builtins.readFile ../../hyprland/hyprland.conf;
  };

  home.pointerCursor = {
    gtk.enable = true;
    package    = pkgs.adwaita-icon-theme;
    name       = "Adwaita";
    size       = 24;
  };

  xdg.configFile = {
    "hypr/hyprlock.conf".source  = ../../hyprland/hyprlock.conf;
    "hypr/hyprpaper.conf".source = ../../hyprland/hyprpaper.conf;
    "waybar/config.jsonc".source = ../../hyprland/waybar/config.jsonc;
    "waybar/style.css".source    = ../../hyprland/waybar/style.css;
    "alacritty/alacritty.toml".source = ../../alacritty.toml;
  };
}
