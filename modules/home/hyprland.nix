{ pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable      = true;
    xwayland.enable = true;
    # Hyprland uses the Lua config now (hyprlang/.conf is gone), so we ship
    # hyprland.lua directly via xdg.configFile below instead of the module's
    # hyprlang generator.
  };

  # The shared hyprland.lua autostarts polkit from /usr/lib (Gentoo/Arch path),
  # which doesn't exist on NixOS — start the Nix-store agent as a user service.
  systemd.user.services.polkit-gnome = {
    Unit = {
      Description = "polkit-gnome authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    package    = pkgs.adwaita-icon-theme;
    name       = "Adwaita";
    size       = 24;
  };

  xdg.configFile = {
    "hypr/hyprland.lua".source   = ../../hyprland/hyprland.lua;
    "hypr/hyprlock.conf".source  = ../../hyprland/hyprlock.conf;
    "hypr/hyprpaper.conf".source = ../../hyprland/hyprpaper.conf;
    "hypr/wallpaper.jpg".source  = ../../wallpapers/nixos.jpg;
    "waybar/config.jsonc".source = ../../hyprland/waybar/config.jsonc;
    "waybar/style.css".source    = ../../hyprland/waybar/style.css;
    "alacritty/alacritty.toml".source = ../../alacritty.toml;
  };
}
