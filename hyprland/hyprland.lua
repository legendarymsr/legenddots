-- Hyprland config in Lua (the hl.* API). A faithful 1:1 port of hyprland.conf —
-- same monitors, autostart, env, settings, animations, window rules, and binds.
-- Tokyo Night. Docs: https://wiki.hypr.land/
--
-- Dispatchers the reference sample demonstrated use native hl.dsp.*; the few it
-- didn't (cyclenext, fullscreen, layoutmsg, directional movewindow, resizeactive)
-- go through `hyprctl dispatch` so they behave byte-identically to the .conf.
-- The original hyprland.conf is kept untouched as a fallback.

------------------
---- MONITORS ----
------------------
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("sleep 1 && waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-----------------
---- INPUT -------
-----------------
hl.config({
    input = {
        kb_layout     = "se",
        follow_mouse  = 1,
        sensitivity   = 0.2,
        accel_profile = "flat",
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
        },
    },
})

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(7aa2f7ff)", "rgba(bb9af7ff)" }, angle = 45 },
            inactive_border = "rgba(414868ff)",
        },
        layout           = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding         = 8,
        active_opacity   = 1.0,
        inactive_opacity = 0.92,
        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = "rgba(00000066)",
        },
        blur = {
            enabled = true,
            size    = 6,
            passes  = 3,
            xray    = false,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
    },
})

-- bezier curves + animations
hl.curve("easeOut",   { type = "bezier", points = { { 0.16, 1 }, { 0.3,  1 } } })
hl.curve("easeInOut", { type = "bezier", points = { { 0.87, 0 }, { 0.13, 1 } } })
hl.curve("linear",    { type = "bezier", points = { { 0,    0 }, { 1,    1 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "easeOut",   style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "easeOut",   style = "slide" })
hl.animation({ leaf = "border",     enabled = true, speed = 6, bezier = "linear" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "easeInOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeInOut", style = "slidevert" })

----------------------
---- WINDOW RULES ----
----------------------
hl.window_rule({ name = "alacritty-opacity", match = { class = "^(Alacritty)$" },            opacity = "0.95 0.90" })
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(pavucontrol)$" },          float = true })
hl.window_rule({ name = "float-nm-editor",   match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ name = "float-pip",         match = { title = "^(Picture-in-Picture)$" },   float = true })

---------------------
---- KEYBINDINGS ----
---------------------
local mod = "SUPER"

hl.bind(mod .. " + Return",        hl.dsp.exec_cmd("alacritty"))
hl.bind(mod .. " + D",             hl.dsp.exec_cmd("fuzzel"))
hl.bind(mod .. " + B",             hl.dsp.exec_cmd("brave-origin-nightly"))
hl.bind(mod .. " + Escape",        hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + SHIFT + Q",     hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + E",     hl.dsp.exit())
hl.bind(mod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",             hl.dsp.window.pseudo())
-- These map to classic dispatchers the reference sample didn't show, so they go
-- through `hyprctl dispatch` — byte-identical to the hyprland.conf behaviour.
hl.bind(mod .. " + Tab", hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))               -- was: cyclenext
hl.bind(mod .. " + F",   hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))            -- was: fullscreen, 0
hl.bind(mod .. " + T",   hl.dsp.exec_cmd("hyprctl dispatch layoutmsg togglesplit"))  -- was: layoutmsg, togglesplit

-- focus (hjkl)
hl.bind(mod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + j", hl.dsp.focus({ direction = "down" }))

-- move window (Shift+hjkl) — classic `movewindow l/r/u/d`
hl.bind(mod .. " + SHIFT + h", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mod .. " + SHIFT + l", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mod .. " + SHIFT + k", hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mod .. " + SHIFT + j", hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))

-- resize active (Ctrl+hjkl) — classic `resizeactive <dx> <dy>`
hl.bind(mod .. " + CTRL + h", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -40 0"))
hl.bind(mod .. " + CTRL + l", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 40 0"))
hl.bind(mod .. " + CTRL + k", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -40"))
hl.bind(mod .. " + CTRL + j", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 40"))

-- workspaces 1-9 (focus) + move active window to workspace
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- mouse move/resize (drag)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- volume / brightness (locked = works while locked; repeating = key-repeat)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })

-- screenshots (long-string [[ ]] to keep the inner quotes literal)
hl.bind("Print",         hl.dsp.exec_cmd([[bash -c 'grim -g "$(slurp)" - | tee "$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png" | wl-copy']]))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd([[bash -c 'grim - | tee "$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png" | wl-copy']]))
