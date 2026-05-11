{ pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings = {

      # ── Monitors ───────────────────────────────────────────────────────────
      monitor = [ ",preferred,auto,1" ];

      # ── Startup ────────────────────────────────────────────────────────────
      "exec-once" = [
        "hyprpaper"
        "waybar"
        "dunst"
        # polkit handled by systemd.user.services below
      ];

      # ── Environment ────────────────────────────────────────────────────────
      env = [
        "XCURSOR_SIZE,24"
        "XCURSOR_THEME,Adwaita"
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
      ];

      # ── Input ──────────────────────────────────────────────────────────────
      input = {
        kb_layout     = "us";
        follow_mouse  = 1;
        sensitivity   = 0.2;
        accel_profile = "flat";
        touchpad = {
          natural_scroll       = true;
          "tap-to-click"       = true;
          disable_while_typing = true;
        };
      };

      # ── General ────────────────────────────────────────────────────────────
      general = {
        gaps_in               = 5;
        gaps_out              = 10;
        border_size           = 2;
        "col.active_border"   = "rgba(7aa2f7ff) rgba(bb9af7ff) 45deg";
        "col.inactive_border" = "rgba(414868ff)";
        layout                = "dwindle";
        resize_on_border      = true;
      };

      # ── Decoration ─────────────────────────────────────────────────────────
      decoration = {
        rounding         = 8;
        active_opacity   = 1.0;
        inactive_opacity = 0.92;
        shadow = {
          enabled      = true;
          range        = 12;
          render_power = 3;
          color        = "rgba(0,0,0,0.4)";
        };
        blur = {
          enabled           = true;
          size              = 6;
          passes            = 3;
          new_optimizations = true;
          xray              = false;
        };
      };

      # ── Animations ─────────────────────────────────────────────────────────
      animations = {
        enabled = true;
        bezier = [
          "easeOut,   0.16, 1, 0.3, 1"
          "easeInOut, 0.87, 0, 0.13, 1"
          "linear,    0,    0, 1,    1"
        ];
        animation = [
          "windows,    1, 4, easeOut,   slide"
          "windowsOut, 1, 4, easeOut,   slide"
          "border,     1, 6, linear"
          "fade,       1, 4, easeInOut"
          "workspaces, 1, 5, easeInOut, slidevert"
        ];
      };

      # ── Layout ─────────────────────────────────────────────────────────────
      dwindle = {
        pseudotile     = true;
        preserve_split = true;
      };

      # ── Misc ───────────────────────────────────────────────────────────────
      misc = {
        disable_hyprland_logo    = true;
        disable_splash_rendering = true;
        force_default_wallpaper  = 0;
        vfr                      = true;
      };

      # ── Window Rules ───────────────────────────────────────────────────────
      windowrulev2 = [
        "opacity 0.95 0.90, class:^(Alacritty)$"
        "float, class:^(pavucontrol)$"
        "float, class:^(nm-connection-editor)$"
        "float, title:^(Picture-in-Picture)$"
      ];

      # ── Keybinds ───────────────────────────────────────────────────────────
      "$mod" = "SUPER";

      bind = [
        # Apps
        "$mod, Return,      exec, alacritty"
        "$mod, D,           exec, fuzzel"
        "$mod, B,           exec, brave"
        "$mod SHIFT, Q,     killactive"
        "$mod, Q,           exit"
        "$mod, Tab,         cyclenext"
        "$mod, Escape,      exec, hyprlock"
        "$mod, F,           fullscreen, 0"
        "$mod SHIFT, Space, togglefloating"
        "$mod, P,           pseudo"
        "$mod, J,           togglesplit"
        # Focus
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        # Move
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"
        # Resize
        "$mod CTRL, H, resizeactive, -40 0"
        "$mod CTRL, L, resizeactive,  40 0"
        "$mod CTRL, K, resizeactive,  0 -40"
        "$mod CTRL, J, resizeactive,  0  40"
        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        # Move to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        # Screenshots
        ", Print,      exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim - | wl-copy"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      bindel = [
        ", XF86AudioRaiseVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"
        ", XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"
        ", XF86MonBrightnessUp,   exec, brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];
    };
  };

  # ── Config files (not managed by the Hyprland module) ──────────────────────
  xdg.configFile = {
    "hypr/hyprlock.conf".source       = ../hyprland/hyprlock.conf;
    "hypr/hyprpaper.conf".source      = ../hyprland/hyprpaper.conf;
    "waybar/config.jsonc".source      = ../hyprland/waybar/config.jsonc;
    "waybar/style.css".source         = ../hyprland/waybar/style.css;
    "alacritty/alacritty.toml".source = ../alacritty.toml;
  };

  # ── Polkit agent ───────────────────────────────────────────────────────────
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy    = [ "hyprland-session.target" ];
    wants       = [ "hyprland-session.target" ];
    after       = [ "hyprland-session.target" ];
    serviceConfig = {
      Type           = "simple";
      ExecStart      = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart        = "on-failure";
      RestartSec     = 1;
      TimeoutStopSec = 10;
    };
  };
}
