-- ~/.config/xmonad/xmonad.hs — legenddots (minimal)
-- Super mod, alacritty, rofi, a dead-simple xmobar. Mod-q recompiles live.

import XMonad
import XMonad.Hooks.ManageDocks (docks, avoidStruts, manageDocks, ToggleStruts(..))
import XMonad.Util.EZConfig     (additionalKeysP)
import XMonad.Util.SpawnOnce    (spawnOnce)

main :: IO ()
main = xmonad $ docks def
  { modMask            = mod4Mask            -- Super
  , terminal           = "alacritty"
  , borderWidth        = 2
  , normalBorderColor  = "#1a1b26"
  , focusedBorderColor = "#7aa2f7"
  , layoutHook         = avoidStruts (layoutHook def)
  , manageHook         = manageDocks <+> manageHook def
  , startupHook        = startup
  } `additionalKeysP`
  [ ("M-<Return>", spawn "alacritty")
  , ("M-p",        spawn "rofi -show drun")
  , ("M-S-c",      kill)
  , ("M-<Space>",  sendMessage NextLayout)
  , ("M-b",        sendMessage ToggleStruts)   -- show/hide the bar
  , ("M-S-l",      spawn "physlock")           -- TTY-style lock (all VTs)
  , ("M-q",        spawn "xmonad --recompile && xmonad --restart")
  ]

startup :: X ()
startup = do
  spawnOnce "xmobar ~/.xmobarrc &"
  spawnOnce "picom &"
  spawnOnce "dunst &"
