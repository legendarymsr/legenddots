-- ~/.xmonad/xmonad.hs — legenddots · KISS
-- =============================================================================
-- The whole window manager, configured in one Haskell file.
--
-- WHY XMONAD ON KISS (not dwm): KISS is about SIMPLE, not merely small. dwm
-- makes you edit config.h in C and recompile the window manager by hand for
-- every change. XMonad keeps the same tiling minimalism, but this file IS the
-- config — reload it live with Mod-q and XMonad recompiles itself. No C surgery
-- to move a keybind. The one honest cost is GHC (Haskell) at build time; the
-- running WM stays tiny.
--
-- Mod = Super (the "Windows"/Command key). Terminal = st, launcher = dmenu,
-- both from the KISS xorg repo. The imports below come from xmonad-contrib.
-- =============================================================================

import XMonad
import XMonad.Hooks.ManageDocks   (avoidStruts, docks, manageDocks)
import XMonad.Hooks.EwmhDesktops  (ewmh)
import XMonad.Layout.Spacing      (spacingWithEdge)
import XMonad.Util.EZConfig       (additionalKeysP)
import qualified XMonad.StackSet as W

main :: IO ()
main = xmonad . docks . ewmh $ def
  { modMask            = mod4Mask                 -- Super
  , terminal           = "st"
  , borderWidth        = 2
  , normalBorderColor  = "#1a1b26"                -- Tokyo Night bg
  , focusedBorderColor = "#7aa2f7"                -- Tokyo Night blue
  , workspaces         = map show [1 .. 9 :: Int]
  , layoutHook         = myLayout
  , manageHook         = manageDocks <+> manageHook def
  } `additionalKeysP` myKeys

-- Master/stack tiling and a fullscreen layout, with a small gap so windows
-- breathe. avoidStruts leaves room for a bar (dwlb-style) if you add one later.
myLayout = avoidStruts (tiled ||| Full)
  where
    tiled = spacingWithEdge 6 $ Tall nmaster delta ratio
    nmaster = 1        -- windows in the master pane
    ratio   = 1 / 2    -- master pane fraction of the screen
    delta   = 3 / 100  -- resize step

-- Keys in "M-" (Emacs-style) notation; here M = Super.
myKeys :: [(String, X ())]
myKeys =
  [ ("M-<Return>", spawn "st")                              -- terminal
  , ("M-p",        spawn "dmenu_run")                       -- launcher
  , ("M-S-c",      kill)                                    -- close window
  , ("M-<Space>",  sendMessage NextLayout)                  -- cycle layouts
  , ("M-j",        windows W.focusDown)                     -- focus next
  , ("M-k",        windows W.focusUp)                       -- focus prev
  , ("M-S-j",      windows W.swapDown)                      -- move window down
  , ("M-S-k",      windows W.swapUp)                        -- move window up
  , ("M-h",        sendMessage Shrink)                      -- shrink master
  , ("M-l",        sendMessage Expand)                      -- grow master
  , ("M-<Tab>",    windows W.focusDown)                     -- fast cycle
  , ("M-q",        spawn "xmonad --recompile && xmonad --restart")  -- reload this file
  ]
-- (Mod-Shift-q quits XMonad — the XMonad default — which with startx drops you
-- back to the tty. Left as-is on purpose.)
