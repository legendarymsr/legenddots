-- ~/.config/xmonad/xmonad.hs — legenddots (minimal)
-- The whole WM in one file. Super mod, alacritty, dmenu, a lean xmobar.
-- Mod-q recompiles this file live.

import XMonad
import XMonad.Hooks.StatusBar      (statusBarProp, withEasySB, defToggleStrutsKey)
import XMonad.Hooks.StatusBar.PP
import XMonad.Util.EZConfig        (additionalKeysP)
import XMonad.Util.SpawnOnce       (spawnOnce)

main :: IO ()
main = xmonad
     . withEasySB (statusBarProp "xmobar ~/.xmobarrc" (pure pp)) defToggleStrutsKey
     $ def
        { modMask            = mod4Mask            -- Super
        , terminal           = "alacritty"
        , borderWidth        = 2
        , normalBorderColor  = "#1a1b26"
        , focusedBorderColor = "#7aa2f7"
        , startupHook        = spawnOnce "picom &"
        } `additionalKeysP`
        [ ("M-<Return>", spawn "alacritty")
        , ("M-p",        spawn "dmenu_run")
        , ("M-S-c",      kill)
        , ("M-<Space>",  sendMessage NextLayout)
        , ("M-q",        spawn "xmonad --recompile && xmonad --restart")
        ]
  where
    pp = def
      { ppCurrent = xmobarColor "#7aa2f7" "" . wrap "[" "]"
      , ppTitle   = xmobarColor "#c0caf5" "" . shorten 50
      , ppSep     = "  |  "
      }
