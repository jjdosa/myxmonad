{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE RecordWildCards #-}

import Control.Monad (guard)
import Data.Map qualified as M
import Data.Maybe (fromMaybe, isJust)
import Data.Ratio ((%))
import System.Exit (exitSuccess)
import System.IO (hPutStrLn)
import XMonad
  ( ChangeLayout (NextLayout)
  , Default (def)
  , IncMasterN (IncMasterN)
  , KeyMask
  , ManageHook
  , Resize (Expand, Shrink)
  , Window
  , X
  , XConfig (borderWidth, handleEventHook, layoutHook, logHook, manageHook, modMask, startupHook, terminal)
  , XState (windowset)
  , appName
  , className
  , composeAll
  , doF
  , doFloat
  , floatLocation
  , gets
  , io
  , mod1Mask
  , mod4Mask
  , resource
  , screenWorkspace
  , sendMessage
  , spawn
  , stringProperty
  , title
  , whenJust
  , windows
  , withFocused
  , xmonad
  , (<+>)
  , (=?)
  )
import XMonad.Actions.CopyWindow (kill1)
import XMonad.Actions.CycleWS (WSType (..), anyWS, moveTo, nextScreen, prevScreen, shiftNextScreen, shiftPrevScreen, shiftTo, toggleWS)
import XMonad.Actions.FloatKeys (keysMoveWindow, keysResizeWindow)
import XMonad.Actions.MouseResize (mouseResize)
import XMonad.Actions.RepeatAction (rememberActions)
import XMonad.Actions.RotSlaves (rotAllDown, rotSlavesDown)
import XMonad.Actions.WindowGo (runOrRaise)
import XMonad.Actions.WithAll (killAll, sinkAll)
import XMonad.Core (trace)
import XMonad.Hooks.DynamicLog (PP (..), dynamicLogWithPP, shorten, wrap, xmobarColor, xmobarPP)
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen, fullscreenEventHook, setEwmhActivateHook)
import XMonad.Hooks.ManageDocks (ToggleStruts (..), avoidStruts)
import XMonad.Hooks.ManageHelpers (Side (CE), doSideFloat, isDialog)
import XMonad.Hooks.RefocusLast (refocusLastLayoutHook, swapWithLast, toggleFocus)
import XMonad.Hooks.SetWMName (setWMName)
import XMonad.Hooks.WorkspaceHistory (workspaceHistoryHook)
import XMonad.Layout (Full (Full), JumpToLayout (JumpToLayout), (|||))
import XMonad.Layout.Gaps (Direction2D (..), GapMessage (..), gaps)
import XMonad.Layout.Groups.Helpers (swapMaster)
import XMonad.Layout.LayoutModifier (ModifiedLayout)
import XMonad.Layout.LimitWindows (decreaseLimit, increaseLimit, limitWindows)
import XMonad.Layout.MultiToggle (EOT (EOT), mkToggle, single, (??))
import XMonad.Layout.MultiToggle qualified as MT
import XMonad.Layout.MultiToggle.Instances (StdTransformers (MIRROR, NBFULL))
import XMonad.Layout.NoBorders (noBorders)
import XMonad.Layout.Renamed (Rename (Replace), renamed)
import XMonad.Layout.ResizableTile (MirrorResize (MirrorExpand, MirrorShrink), ResizableTall (ResizableTall))
import XMonad.Layout.ShowWName (showWName')
import XMonad.Layout.SimplestFloat (simplestFloat)
import XMonad.Layout.Spacing (Border (Border), Spacing, decScreenSpacing, decWindowSpacing, incScreenSpacing, incWindowSpacing, spacingRaw)
import XMonad.Layout.ToggleLayouts qualified as T
import XMonad.Layout.WindowArranger (WindowArrangerMsg (..), windowArrange)
import XMonad.Layout.WindowNavigation (windowNavigation)
import XMonad.ManageHook ((-->))
import XMonad.Prompt (Direction1D (Next, Prev))
import XMonad.StackSet qualified as W
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Util.NamedScratchpad (NamedScratchpad (..), customFloating, dynamicNSPAction, namedScratchpadAction, namedScratchpadManageHook, toggleDynamicNSP)
import XMonad.Util.Run (safeSpawn, spawnPipe)
import XMonad.Layout.GridVariants (Grid(Grid))


main :: IO ()
main = do
  xmproc0 <- spawnPipe "xmobar -x 0 $HOME/.config/xmobar/xmobarrc"
  xmproc1 <- spawnPipe "xmobar -x 1 $HOME/.config/xmobar/xmobarrc"
  xmproc2 <- spawnPipe "xmobar -x 2 $HOME/.config/xmobar/xmobarrc"

  let conf =
        def
          { modMask = myModMask
          , terminal = myTerminal
          , startupHook = myStartupHook
          , manageHook = myManageHook <+> namedScratchpadManageHook scratchpads
          , layoutHook = refocusLastLayoutHook $ showWName' def myLayoutHook
          , borderWidth = 0
          , logHook =
              workspaceHistoryHook
                <+> dynamicLogWithPP
                  xmobarPP
                    { ppOutput = \x -> hPutStrLn xmproc0 x >> hPutStrLn xmproc1 x >> hPutStrLn xmproc2 x
                    , ppCurrent = xmobarColor "#98be65" "" . wrap "[" "]" -- Current workspace in xmobar
                    , ppVisible = xmobarColor "#98be65" "" -- Visible but not current workspace
                    , ppHidden = xmobarColor "#82AAFF" "" . wrap "*" "" -- Hidden workspaces in xmobar
                    , ppHiddenNoWindows = xmobarColor "#c792ea" "" -- Hidden workspaces (no windows)
                    , ppTitle = xmobarColor "#b3afc2" "" . shorten 60 -- Title of active window in xmobar
                    , ppSep = "<fc=#666666> <fn=1>|</fn> </fc>" -- Separators in xmobar
                    , ppUrgent = xmobarColor "#C45500" "" . wrap "!" "!" -- Urgent workspace
                    , ppExtras = [windowCount] -- # of windows current workspace
                    , ppOrder = \(ws : l : t : ex) -> [ws, l] ++ ex ++ [t]
                    }
          }

  xmonad $
    ewmh $
      conf
        `additionalKeysP` rememberActions "M-." myKeyBindings


myModMask :: KeyMask
myModMask = mod4Mask -- Sets modkey to super/windows key


myTerminal :: String
myTerminal = "alacritty" -- Sets default terminal


myBrowser :: String
myBrowser = "brave"


myScreenLocker :: String
myScreenLocker = "i3lock-fancy-rapid 10 pixel"


myEditor :: String
myEditor = "emacsclient -s doom -c -a 'emacs --with-profile doom --fg-daemon'" -- Sets emacs as editor for tree select
-- myEditor = myTerminal ++ " -e vim "    -- Sets vim as editor for tree select

myEditor2 :: String
myEditor2 = "emacsclient -s snd -c -a 'emacs --with-profile doom --fg-daemon=snd'" -- Sets emacs as editor for tree select

myCapture :: String
myCapture = "DIR=~/Dropbox/captures; mkdir -p $DIR; flameshot gui -p $DIR"


myEmail :: String
myEmail = "emacsclient -c -a emacs --eval '(notmuch)'"


myRofi :: String
myRofi = "rofi -modi drun,ssh,window -show drun -show-icons"


myDmenu :: String
myDmenu = "dmenu_run"


altMask :: KeyMask
altMask = mod1Mask -- Setting this for use in xprompts


windowCount :: X (Maybe String)
windowCount = gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset


myStartupHook :: X ()
myStartupHook =
  do
    spawn "xset r rate 350 80"
    spawn "picom -cf -i 0.8 --use-ewmh-active-win"
    <+> setWMName "LG3D"


------------------------------------------------------------------------
--
--   Layout Hook
--

myLayoutHook = avoidStruts $ mouseResize myDefaultLayout
  where
    myDefaultLayout =
      renamed [Replace "tall"] (mkToggleAll tall)
        ||| renamed [Replace "grid"] (mkToggleAll grid)
        ||| renamed [Replace "monocle"] (mkToggleAll (noBorders monocle))
        ||| renamed [Replace "floats"] floats
    mkToggleAll l =
      gaps [(L, 0), (D, 0), (U, 0), (R, 0)] $
        windowArrange $
          T.toggleLayouts floats $
            mkToggle (NBFULL ?? EOT) $
              mkToggle
                (single MIRROR)
                l
    tall = mkLayout $ ResizableTall 1 (3 / 100) (1 / 2) []
    floats = mkLayout simplestFloat
    monocle = mkLayout $ limitWindows 20 Full
    grid = mkLayout $ Grid (16/10)
    mkLayout layout = windowNavigation $ mySpacing 6 layout
      where
        mySpacing :: Integer -> l a -> ModifiedLayout Spacing l a
        mySpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True


------------------------------------------------------------------------
--
--   ManageHooks
--

myManageHook :: ManageHook
myManageHook =
  composeAll . concat $
    [ [resource =? t --> doFloat | t <- byResource]
    , [className =? c --> doFloat | c <- byClass]
    , [title =? t --> doFloat | t <- byTitle]
    , [stringProperty "WM_WINDOW_ROLE" =? r --> doFloat | r <- byRole]
    , [stringProperty "WM_WINDOW_TYPE" =? t --> doFloat | t <- byType]
    , [isDialog --> doFloat]
    ]
  where
    byResource = ["Devtools", "plasmashell"]
    byClass = ["org.gnome.Nautilus", "Gimp"]
    byTitle = ["Open Document", "Open Files", "Developer Tools"]
    byRole = ["pop-up", "GtkFileChooserDialog", "bubble"]
    byType = ["_NET_WM_WINDOW_TYPE_SPLASH", "_NET_WM_WINDOW_TYPE_DIALOG"]


data App
  = ClassApp {name :: String, hook :: ManageHook, cmd :: String}
  | TitleApp {name :: String, hook :: ManageHook, cmd :: String}
  | NameApp {name :: String, hook :: ManageHook, cmd :: String}


scratchpads :: [NamedScratchpad]
scratchpads =
  mkNS
    <$> [ TitleApp "emacs" (customFloating myRightCenter) "emacsclient -s emacs -c -a 'emacs --with-profile doom --title emacs --bg-daemon=emacs'"
        , TitleApp "smi" (customFloating myTopLeft) (myTerminal ++ " -t smi -e bash -c 'watch -n0.1 nvidia-smi")
        , TitleApp "btop" (customFloating myMidLeft) (myTerminal ++ " -t btop -e btop")
        , TitleApp "tmux" (customFloating myBtmLeft) (myTerminal ++ " -t tmux -e tmux")
        ]
  where
    mkNS TitleApp {..} = NS name cmd (title =? name) hook
    mkNS ClassApp {..} = NS name cmd (className =? name) hook
    mkNS NameApp {..} = NS name cmd (appName =? name) hook


myCenter :: W.RationalRect
myCenter = W.RationalRect (4 / 32) (1 / 32) (24 / 32) (30 / 32)


myFull :: W.RationalRect
myFull = W.RationalRect (0 / 32) (0 / 32) (32 / 32) (32 / 32)


myRight :: W.RationalRect
myRight = W.RationalRect (33 / 64) (1 / 32) (15 / 32) (30 / 32)


myLeft :: W.RationalRect
myLeft = W.RationalRect (1 / 64) (1 / 32) (15 / 32) (30 / 32)


myTopCenter :: W.RationalRect
myTopCenter = W.RationalRect (1 / 32) (1 / 32) (30 / 32) (16 / 32)


myRightCenter :: W.RationalRect
myRightCenter = W.RationalRect (10 / 32) (1 / 32) (21 / 32) (30 / 32) -- px py wx wy


myTopLeft :: W.RationalRect
myTopLeft = W.RationalRect (1 / 32) (1 / 32) (9 / 32) (8 / 32) -- px py wx wy

myMidLeft :: W.RationalRect
myMidLeft = W.RationalRect (1 / 32) (9 / 32) (9 / 32) (10 / 32) -- px py wx wy

myBtmLeft :: W.RationalRect
myBtmLeft = W.RationalRect (1 / 32) (19 / 32) (9 / 32) (12 / 32) -- px py wx wy



------------------------------------------------------------------------
--
--   Key Bindings
--

myKeyBindings =
  [ -- ("M-q"       , spawn "xmonad --recompile; xmonad --restart")
    -- ("M-q"       , spawn "restart-xmonad.sh")
    ("M-C-q"       , spawn "xmonad --recompile; xmonad --restart")
  , ("M-C-S-q", io exitSuccess) -- Quits xmonad
  -- Launch programs
  , ("M-p", spawn myDmenu)
  , ("M-S-p", spawn myRofi)
  , -- ("M-s", spawn "dm-search.sh")
    ("M-S-v", spawn "clipmenu")
  , ("M-C-c", spawn myCapture)
  , -- , ("M-o"                    , spawn "dmenu_run -i -p \"Run: \"")
    ("M-/", spawn "dm-qutebrowser-history.sh")
  , -- Windows navigation
    ("M-S-m", swapMaster) -- Moves focused window to master, others maintain order
  , ("M-C-<Tab>", rotAllDown) -- Rotate all the windows in the current stack
  , ("M-C-S-<Tab>", rotSlavesDown) -- Rotate all windows except master and keep focus in place
  , ("M-n", toggleFocus) -- Move focus to the lastly focused
  , ("M-S-n", swapWithLast) -- Move the focused to the lastly focused
  -- Kill windows
  , ("M-S-c", kill1) -- Kill the currently focused client
  , ("M-C-S-c", killAll) -- Kill all windows on current workspace
  -- Workspaces
  , ("M-[", moveTo Prev anyWS) -- moveTo previous workspace
  , ("M-]", moveTo Next anyWS) -- moveTo next workspace
  , ("M-`", toggleWS)
  , ("M-S-[", shiftTo Prev nonNSP >> moveTo Prev nonNSP) -- Shifts focused window to prev ws and move
  , ("M-S-]", shiftTo Next nonNSP >> moveTo Next nonNSP) -- Shifts focused window to next ws and move
  , ("M-C-[", prevScreen) -- Switch focus to prev monitor
  , ("M-C-]", nextScreen) -- Switch focus to next monitor
  , ("M-C-S-[", shiftPrevScreen >> prevScreen) -- Shifts focused window to prev monitor and move
  , ("M-C-S-]", shiftNextScreen >> nextScreen) -- Shifts focused window to next monitor and move
  -- Floating windows
  , ("M-t", withFocused $ windows . W.sink) -- Push floating window back to tile
  , ("M-S-t", sinkAll) -- Push ALL floating windows to tile
  -- Increase/decrease spacing (gaps)
  , ("M--", decWindowSpacing 1) -- Decrease window spacing
  , ("M-=", incWindowSpacing 1) -- Increase window spacing
  , ("M-S--", decScreenSpacing 1) -- Decrease screen spacing
  , ("M-S-=", incScreenSpacing 1) -- Increase screen spacing
  -- Layouts
  , ("M-<Space>", sendMessage NextLayout)
  , ("M-r", sendMessage $ MT.Toggle MIRROR)
  , ("M-C-M1-<Up>", sendMessage Arrange)
  , ("M-C-M1-<Down>", sendMessage DeArrange)
  , ("M-f", sendMessage (MT.Toggle NBFULL) >> sendMessage ToggleStruts) -- Toggles noborder/full
  , ("M-S-f", sendMessage ToggleStruts)
  , ("M-C-f", sendMessage (T.Toggle "floats")) -- Toggles my 'floats' layout
  , ("M-C-1", sendMessage $ JumpToLayout "tall")
  , ("M-C-2", sendMessage $ JumpToLayout "grid")
  , ("M-C-3", sendMessage $ JumpToLayout "monocle")
  , ("M-C-4", sendMessage $ JumpToLayout "floats")
  , -- Increase/decrease windows in the master pane or the stack
    ("M-S-,", sendMessage (IncMasterN 1)) -- Increase number of clients in master pane
  , ("M-S-.", sendMessage (IncMasterN (-1))) -- Decrease number of clients in master pane
  , ("M-C-,", increaseLimit) -- Increase number of windows
  , ("M-C-.", decreaseLimit) -- Decrease number of windows
  -- Tiled Window resizing
  , ("M-C-h", sendMessage Shrink) -- Shrink horiz window width
  , ("M-C-l", sendMessage Expand) -- Expand horiz window width
  , ("M-C-j", sendMessage MirrorShrink) -- Shrink vert window width
  , ("M-C-k", sendMessage MirrorExpand) -- Exoand vert window width
  -- Floating Window resizing
  , ("M-S-u", withFocused $ keysResizeWindow (0, 10) (0, 0)) -- enlarge down
  , ("M-S-i", withFocused $ keysResizeWindow (0, -10) (0, 0)) -- shrink down
  , ("M-S-y", withFocused $ keysResizeWindow (-10, 0) (0, 0)) -- shrink right
  , ("M-S-o", withFocused $ keysResizeWindow (10, 0) (0, 0)) -- enlarge right
  , ("M-C-u", withFocused $ keysResizeWindow (0, -10) (0, 1)) -- shrink up
  , ("M-C-i", withFocused $ keysResizeWindow (0, 10) (0, 1)) -- enlarge up
  , ("M-C-y", withFocused $ keysResizeWindow (10, 0) (1, 0)) -- enlarge left
  , ("M-C-o", withFocused $ keysResizeWindow (-10, 0) (1, 0)) -- shrink left
  -- Changing Gaps
  , ("M-S-C-u", sendMessage $ DecGap 10 D)
  , ("M-S-C-i", sendMessage $ IncGap 10 D)
  , ("M-S-C-o", sendMessage $ DecGap 10 R)
  , ("M-S-C-y", sendMessage $ IncGap 10 R)
  , ("M-M1-S-C-u", sendMessage $ IncGap 10 U)
  , ("M-M1-S-C-i", sendMessage $ DecGap 10 U)
  , ("M-M1-S-C-o", sendMessage $ IncGap 10 L)
  , ("M-M1-S-C-y", sendMessage $ DecGap 10 L)
  , ("M-g u", sendMessage $ ToggleGap D)
  , ("M-g i", sendMessage $ ToggleGap U)
  , ("M-g o", sendMessage $ ToggleGap R)
  , ("M-g y", sendMessage $ ToggleGap L)
  -- Floating Window moving
  , ("M-i", withFocused $ keysMoveWindow (0, -9))
  , ("M-u", withFocused $ keysMoveWindow (0, 9))
  , ("M-o", withFocused $ keysMoveWindow (16, 0))
  , ("M-y", withFocused $ keysMoveWindow (-16, 0))
  , -- Window floating at a custom position
    ("M-z", withFocused $ floatToRationalRect myLeft)
  , ("M-x", withFocused $ floatToRationalRect myCenter)
  , ("M-c", withFocused $ floatToRationalRect myRightCenter)
  , ("M-v", withFocused $ floatToRationalRect myRight)
  , ("M-b", withFocused $ floatToRationalRect myFull)
  , -- Spawn major apps
    ("M-S-<Return>", spawn $ myTerminal ++ " -e tmux")
  , ("M-C-<Return>", spawn myEditor)
  , ("M-S-C-<Return>", spawn myBrowser)
  , -- Scratchpads
    ("M-C-a", namedScratchpadAction scratchpads "tmux")
  , ("M-C-s", namedScratchpadAction scratchpads "btop")
  , ("M-C-d", namedScratchpadAction scratchpads "smi")
  , -- Dynamic Scratchpads
    ("M-S-a", withFocused $ toggleDynamicNSP "dyn1")
  , ("M-S-s", withFocused $ toggleDynamicNSP "dyn2")
  , ("M-S-d", withFocused $ toggleDynamicNSP "dyn3")
  , ("M-a", dynamicNSPAction "dyn1")
  , ("M-s", dynamicNSPAction "dyn2")
  , ("M-d", dynamicNSPAction "dyn3")
  , -- environment
    ("M-S-C-x", spawn "autorandr")
  , ("M-M1-9", spawn "xbacklight -inc 5")
  , ("M-M1-8", spawn "xbacklight -dec 5")
  , -- Multimedia Keys
    ("<XF86AudioPlay>", spawn (myTerminal ++ " mocp --play"))
  , ("<XF86AudioPrev>", spawn (myTerminal ++ " mocp --previous"))
  , ("<XF86AudioNext>", spawn (myTerminal ++ " mocp --next"))
  , ("<XF86AudioMute>", spawn "amixer set Master toggle")
  , ("<XF86AudioLowerVolume>", spawn "amixer set Master 5%- unmute")
  , ("<XF86AudioRaiseVolume>", spawn "amixer set Master 5%+ unmute")
  , ("<XF86MonBrightnessUp>", spawn "xbacklight -inc 5")
  , ("<XF86MonBrightnessDown>", spawn "xbacklight -dec 5")
  , ("<XF86Favorites>", spawn myScreenLocker)
  , ("<F12>", spawn myScreenLocker)
  , ("M-M1-C-S-l", spawn myScreenLocker)
  , ("<XF86HomePage>", spawn myBrowser)
  , ("<XF86Search>", safeSpawn myBrowser ["https://hoogle.hackage.org"])
  , ("<XF86Mail>", spawn myEmail)
  , ("<XF86Calculator>", runOrRaise "qalculate-gtk" (resource =? "qalculate-gtk"))
  , ("<XF86Eject>", spawn "toggleeject")
  , ("<Print>", spawn "scrotd 0")
  ]
    -- screen view and shift
    ++ [ ("M-" ++ m ++ k, screenWorkspace sc >>= flip whenJust (windows . f))
       | (k, sc) <- zip ["q", "w", "e"] [1, 0, 2]
       , (f, m) <- [(W.view, ""), (W.shift, "S-")]
       ]
  where
    -- The following lines are needed for named scratchpads.
    nonNSP = WSIs (return (\ws -> W.tag ws /= "NSP"))
    nonEmptyNonNSP = WSIs (return (\ws -> isJust (W.stack ws) && W.tag ws /= "NSP"))


------------------------------------------------------------------------
--
--   Custom Unitity Functions
--

{- | Make a tiled window floating, using the rectangle given as the argument,
   mofified the `float` function at
   https://hackage.haskell.org/package/xmonad-0.17.1/docs/src/XMonad.Operations.html#float
-}
floatToRationalRect :: W.RationalRect -> Window -> X ()
floatToRationalRect rr' w = do
  floats <- gets (W.floating . windowset)
  (sc, rr) <- floatLocation w
  if w `M.member` floats && rr `almostSame` rr' -- if the current window is floating...
    then (windows . W.sink) w
    else do
      windows $ \ws -> W.float w rr' . fromMaybe ws $ do
        i <- W.findTag w ws
        guard $ i `elem` map (W.tag . W.workspace) (W.screens ws)
        f <- W.peek ws
        sw <- W.lookupWorkspace sc ws
        return (W.focusWindow f . W.shiftWin sw w $ ws)
  where
    almostSame :: W.RationalRect -> W.RationalRect -> Bool
    almostSame (W.RationalRect px py wx wy) (W.RationalRect px' py' wx' wy') =
      rd px px' <= tol
        && rd py py' <= tol
        && rd wx wx' <= tol
        && rd wy wy' <= tol
      where
        tol = 1 % 100
        rd a b = 2 * abs (a - b) / (a + b) -- relative difference


-- If the window is floating then (f), if tiled then (n)
ifFloatThenElse :: X () -> X () -> X ()
ifFloatThenElse f n = withFocused $ \windowId -> do
  floats <- gets (W.floating . windowset)
  if windowId `M.member` floats -- if the current window is floating...
    then f
    else n


ifFloatThenSinkElse :: X () -> X ()
ifFloatThenSinkElse = ifFloatThenElse (withFocused $ windows . W.sink)
