---@meta
-- Type stub for Hyprland's Lua config API (the `hl` global). NOT executed — it
-- only teaches lua_ls the shape of the runtime-injected `hl`, so editing
-- hyprland.lua gets completion/hover on hl.* and no "undefined global" noise.
-- Derived from Hyprland's default Lua config; extend as the API grows.

---@class hl.dsp.window
local dsp_window = {}
function dsp_window.close() end          -- killactive
---@param opts table  -- e.g. { action = "toggle" }
function dsp_window.float(opts) end        -- togglefloating / setfloating
function dsp_window.pseudo() end           -- pseudo
---@param opts table  -- { workspace = n } | { direction = "left"|"right"|"up"|"down" }
function dsp_window.move(opts) end         -- movetoworkspace / movewindow
function dsp_window.drag() end             -- movewindow (mouse)
---@param opts? table
function dsp_window.resize(opts) end       -- resizewindow / resizeactive
---@param opts? table  -- { mode = 0|1|2 }
function dsp_window.fullscreen(opts) end   -- fullscreen

---@class hl.dsp
---@field window hl.dsp.window
local dsp = {}
---@param cmd string
function dsp.exec_cmd(cmd) end             -- exec
function dsp.exit() end                    -- exit
---@param opts table  -- { direction = ... } | { workspace = n | "e+1" } | { cycle = "next"|"prev" }
function dsp.focus(opts) end               -- movefocus / workspace
---@param msg string
function dsp.layoutmsg(msg) end            -- layoutmsg

---@class hl
---@field dsp hl.dsp
hl = {}

---@param opts table
function hl.monitor(opts) end
---@param event string
---@param fn fun()
function hl.on(event, fn) end
---@param cmd string
function hl.exec_cmd(cmd) end
---@param name string
---@param value string
function hl.env(name, value) end
---@param opts table
function hl.config(opts) end
---@param name string
---@param def table
function hl.curve(name, def) end
---@param opts table
function hl.animation(opts) end
---@param opts table
function hl.window_rule(opts) end
---@param opts table
function hl.gesture(opts) end
---@param keys string
---@param action any
---@param opts? table  -- { mouse = true, locked = true, repeating = true }
function hl.bind(keys, action, opts) end
