-- ~/.config/xmonad/xmonad.hs — legenddots
-- =============================================================================
-- The whole window manager, configured in one Haskell file — the XMonad rice
-- counterpart to i3/config. Tokyo Night, Super mod, alacritty + rofi, xmobar
-- for the bar, picom/dunst/feh on startup. Reload live with Mod-q (XMonad
-- recompiles this file itself — no C patching like dwm).
-- =============================================================================

import XMonad
import XMonad.Hooks.EwmhDesktops   (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageHelpers  (isDialog, doCenterFloat)
import XMonad.Hooks.StatusBar      (statusBarProp, withEasySB, defToggleStrutsKey)
import XMonad.Hooks.StatusBar.PP
import XMonad.Layout.Spacing       (spacingWithEdge)
import XMonad.Util.EZConfig        (additionalKeysP)
import XMonad.Util.SpawnOnce       (spawnOnce)
import qualified XMonad.StackSet as W

myTerminal, myLauncher :: String
myTerminal = "alacritty"
myLauncher = "rofi -show drun"

-- withEasySB wraps the layout in AvoidStruts and binds Mod-b to toggle the bar,
-- and statusBarProp feeds xmobar over the _XMONAD_LOG property (see xmobarrc).
main :: IO ()
main = xmonad
     . ewmhFullscreen
     . ewmh
     . withEasySB (statusBarProp "xmobar ~/.config/xmobar/xmobarrc" (pure myPP)) defToggleStrutsKey
     $ myConfig

myConfig = def
  { modMask            = mod4Mask                 -- Super
  , terminal           = myTerminal
  , borderWidth        = 2
  , normalBorderColor  = "#1a1b26"                -- Tokyo Night bg
  , focusedBorderColor = "#7aa2f7"                -- Tokyo Night blue
  , workspaces         = map show [1 .. 9 :: Int]
  , layoutHook         = myLayout
  , manageHook         = myManageHook
  , startupHook        = myStartup
  } `additionalKeysP` myKeys

-- Master/stack tiling with gaps, plus a fullscreen layout. (AvoidStruts is
-- added by withEasySB, so the bar is never covered — don't add it here too.)
myLayout = tiled ||| Full
  where
    tiled   = spacingWithEdge 6 $ Tall nmaster delta ratio
    nmaster = 1
    ratio   = 1 / 2
    delta   = 3 / 100

myManageHook :: ManageHook
myManageHook = composeAll
  [ isDialog --> doCenterFloat ]

-- Started once per session (spawnOnce won't double-launch on Mod-q reload).
myStartup :: X ()
myStartup = do
  spawnOnce "picom &"
  spawnOnce "dunst &"
  spawnOnce "setxkbmap se"
  spawnOnce "feh --bg-fill ~/.config/xmonad/wallpaper.jpg"

-- xmobar log formatting (Tokyo Night).
myPP :: PP
myPP = def
  { ppCurrent         = xmobarColor "#7aa2f7" "" . wrap "[" "]"
  , ppHidden          = xmobarColor "#c0caf5" ""
  , ppHiddenNoWindows = xmobarColor "#414868" ""
  , ppUrgent          = xmobarColor "#f7768e" "" . wrap "!" "!"
  , ppTitle           = xmobarColor "#c0caf5" "" . shorten 60
  , ppLayout          = xmobarColor "#bb9af7" ""
  , ppSep             = xmobarColor "#414868" "" "  |  "
  }

-- Keys in "M-" (Emacs-style) notation; M = Super. Mod-b (toggle bar) is bound
-- by withEasySB above.
myKeys :: [(String, X ())]
myKeys =
  [ ("M-<Return>",   spawn myTerminal)
  , ("M-p",          spawn myLauncher)
  , ("M-S-c",        kill)
  , ("M-<Space>",    sendMessage NextLayout)
  , ("M-j",          windows W.focusDown)
  , ("M-k",          windows W.focusUp)
  , ("M-S-j",        windows W.swapDown)
  , ("M-S-k",        windows W.swapUp)
  , ("M-S-<Return>", windows W.swapMaster)
  , ("M-h",          sendMessage Shrink)
  , ("M-l",          sendMessage Expand)
  , ("M-<Tab>",      windows W.focusDown)
  , ("<Print>",      spawn "maim -s | xclip -selection clipboard -t image/png")
  , ("M-q",          spawn "xmonad --recompile && xmonad --restart")
  ]
-- (Mod-Shift-q quits XMonad — the XMonad default — which with startx drops you
-- back to the tty.)
