static const unsigned int borderpx = 2;
static const unsigned int snap = 32;
static const int showbar = 1;
static const int topbar = 1;
static const char *fonts[] = { "JetBrainsMono Nerd Font:size=11" };
static const char dmenufont[] = "JetBrainsMono Nerd Font:size=11";
static const char col_bg[] = "#1a1b26";
static const char col_fg[] = "#c0caf5";
static const char col_gray[] = "#414868";
static const char col_accent[] = "#7aa2f7";
static const char col_urgent[] = "#f7768e";
static const char *colors[][3] = {
 [SchemeNorm] = { col_fg, col_bg, col_gray },
 [SchemeSel] = { col_bg, col_accent, col_accent },
};
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };
static const Rule rules[] = {
 { "Gimp", NULL, NULL, 0, 1, -1 },
 { "IceCat", NULL, NULL, 1 << 8, 0, -1 },
};
static const float mfact = 0.55;
static const int nmaster = 1;
static const int resizehints = 1;
static const int lockfullscreen = 1;
static const Layout layouts[] = {
 { "[]=", tile },
 { "><>", NULL },
 { "[M]", monocle },
};
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
 { MODKEY, KEY, view, {.ui = 1 << TAG} }, \
 { MODKEY|ControlMask, KEY, toggleview, {.ui = 1 << TAG} }, \
 { MODKEY|ShiftMask, KEY, tag, {.ui = 1 << TAG} }, \
 { MODKEY|ControlMask|ShiftMask, KEY, toggletag, {.ui = 1 << TAG} },
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }
static char dmenumon[2] = "0";
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont,
 "-nb", col_bg, "-nf", col_fg, "-sb", col_accent, "-sf", col_bg, NULL };
static const char *termcmd[] = { "st", NULL };
static const Key keys[] = {
 { MODKEY, XK_d, spawn, {.v = dmenucmd } },
 { MODKEY, XK_Return, spawn, {.v = termcmd } },
 { MODKEY, XK_b, spawn, SHCMD("icecat") },
 { MODKEY, XK_e, spawn, SHCMD("emacs") },
 { MODKEY, XK_Escape, spawn, SHCMD("slock") },
 { MODKEY|ShiftMask, XK_b, togglebar, {0} },
 { MODKEY, XK_j, focusstack, {.i = +1 } },
 { MODKEY, XK_k, focusstack, {.i = -1 } },
 { MODKEY, XK_i, incnmaster, {.i = +1 } },
 { MODKEY, XK_o, incnmaster, {.i = -1 } },
 { MODKEY, XK_h, setmfact, {.f = -0.05} },
 { MODKEY, XK_l, setmfact, {.f = +0.05} },
 { MODKEY, XK_space, zoom, {0} },
 { MODKEY, XK_Tab, view, {0} },
 { MODKEY|ShiftMask, XK_q, killclient, {0} },
 { MODKEY, XK_t, setlayout, {.v = &layouts[0]} },
 { MODKEY, XK_f, setlayout, {.v = &layouts[1]} },
 { MODKEY, XK_m, setlayout, {.v = &layouts[2]} },
 { MODKEY|ShiftMask, XK_space, togglefloating, {0} },
 { MODKEY, XK_0, view, {.ui = ~0 } },
 { MODKEY|ShiftMask, XK_0, tag, {.ui = ~0 } },
 { MODKEY, XK_comma, focusmon, {.i = -1 } },
 { MODKEY, XK_period, focusmon, {.i = +1 } },
 { MODKEY|ShiftMask, XK_comma, tagmon, {.i = -1 } },
 { MODKEY|ShiftMask, XK_period, tagmon, {.i = +1 } },
 TAGKEYS( XK_1, 0)
 TAGKEYS( XK_2, 1)
 TAGKEYS( XK_3, 2)
 TAGKEYS( XK_4, 3)
 TAGKEYS( XK_5, 4)
 TAGKEYS( XK_6, 5)
 TAGKEYS( XK_7, 6)
 TAGKEYS( XK_8, 7)
 TAGKEYS( XK_9, 8)
 { MODKEY|ShiftMask, XK_e, quit, {0} },
};
static const Button buttons[] = {
 { ClkLtSymbol, 0, Button1, setlayout, {0} },
 { ClkLtSymbol, 0, Button3, setlayout, {.v = &layouts[2]} },
 { ClkWinTitle, 0, Button2, zoom, {0} },
 { ClkStatusText, 0, Button2, spawn, {.v = termcmd } },
 { ClkClientWin, MODKEY, Button1, movemouse, {0} },
 { ClkClientWin, MODKEY, Button2, togglefloating, {0} },
 { ClkClientWin, MODKEY, Button3, resizemouse, {0} },
 { ClkTagBar, 0, Button1, view, {0} },
 { ClkTagBar, 0, Button3, toggleview, {0} },
 { ClkTagBar, MODKEY, Button1, tag, {0} },
 { ClkTagBar, MODKEY, Button3, toggletag, {0} },
};
