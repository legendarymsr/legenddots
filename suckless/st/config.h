/* st — custom minimal config. Tokyo Night, JetBrainsMono Nerd Font.
 *
 * Build-time config for `st-tokyonight` (guix/config.scm), which copies this
 * to config.h before compiling st. Trimmed from st's stock config.def.h:
 *   - no F13–F35 (Shift/Ctrl+F variants) — only F1–F12 exist here
 *   - no keypad (XK_KP_*) table — this machine has no numpad
 *   - no mouse shortcuts — the terminal is keyboard-only
 * Everything st's source references still exists, so it compiles clean.
 */

/* appearance */
static char *font = "JetBrainsMono Nerd Font:pixelsize=14:antialias=true:autohint=true";
static int borderpx = 12;

/* shell / identification */
static char *shell = "/bin/sh";
char *utmp = NULL;
char *scroll = NULL;
char *stty_args = "stty raw pass8 nl -echo -iexten -cstopb 38400";
char *vtiden = "\033[?6c";

/* kerning / character bounding-box multipliers */
static float cwscale = 1.0;
static float chscale = 1.0;

/* word delimiters for double-click selection */
wchar_t *worddelimiters = L" ";

/* selection timeouts (ms) */
static unsigned int doubleclicktimeout = 300;
static unsigned int tripleclicktimeout = 600;

static int allowaltscreen = 1;
static int allowwindowops = 0;

/* draw latency range (ms) */
static double minlatency = 8;
static double maxlatency = 33;

static unsigned int blinktimeout = 800;
static unsigned int cursorthickness = 2;
static int bellvolume = 0;

char *termname = "st-256color";
unsigned int tabspaces = 8;

/* Tokyo Night palette (first 16 used by escape sequences) */
static const char *colorname[] = {
	/* 8 normal */
	"#15161e", "#f7768e", "#9ece6a", "#e0af68",
	"#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6",
	/* 8 bright */
	"#414868", "#f7768e", "#9ece6a", "#e0af68",
	"#7aa2f7", "#bb9af7", "#7dcfff", "#c0caf5",

	[255] = 0,
	"#c0caf5", /* 256 -> foreground */
	"#1a1b26", /* 257 -> background */
	"#c0caf5", /* 258 -> cursor     */
};

unsigned int defaultfg = 256;
unsigned int defaultbg = 257;
unsigned int defaultcs = 258;
static unsigned int defaultrcs = 257;

static unsigned int cursorshape = 2;   /* block */
static unsigned int cols = 100;
static unsigned int rows = 30;

/* mouse cursor look (kept: st.c references these, cheap) */
static unsigned int mouseshape = XC_xterm;
static unsigned int mousefg = 7;
static unsigned int mousebg = 0;

static unsigned int defaultattr = 11;
static uint forcemousemod = ShiftMask;

/* no mouse shortcuts — keyboard-only terminal */
static MouseShortcut mshortcuts[] = { };

/* keyboard shortcuts */
#define MODKEY Mod1Mask
#define TERMMOD (ControlMask|ShiftMask)

static Shortcut shortcuts[] = {
	/* mask                 keysym          function        argument */
	{ XK_ANY_MOD,           XK_Break,       sendbreak,      {.i =  0} },
	{ ControlMask,          XK_Print,       toggleprinter,  {.i =  0} },
	{ ShiftMask,            XK_Print,       printscreen,    {.i =  0} },
	{ XK_ANY_MOD,           XK_Print,       printsel,       {.i =  0} },
	{ TERMMOD,              XK_Prior,       zoom,           {.f = +1} },
	{ TERMMOD,              XK_Next,        zoom,           {.f = -1} },
	{ TERMMOD,              XK_Home,        zoomreset,      {.f =  0} },
	{ TERMMOD,              XK_C,           clipcopy,       {.i =  0} },
	{ TERMMOD,              XK_V,           clippaste,      {.i =  0} },
	{ ShiftMask,            XK_Insert,      selpaste,       {.i =  0} },
	{ TERMMOD,              XK_Num_Lock,    numlock,        {.i =  0} },
};

static KeySym mappedkeys[] = { -1 };
static uint ignoremod = Mod2Mask|XK_SWITCH_MOD;

/*
 * key definitions — F1–F12 and the standard editing/navigation keys with the
 * modifier variants editors (nvim, emacs, tmux) rely on. No F13–F35, no keypad.
 */
static Key key[] = {
	/* keysym           mask                    string      appkey appcursor */
	{ XK_Up,            ShiftMask,              "\033[1;2A",     0,    0},
	{ XK_Up,            Mod1Mask,               "\033[1;3A",     0,    0},
	{ XK_Up,            ControlMask,            "\033[1;5A",     0,    0},
	{ XK_Up,            XK_ANY_MOD,             "\033[A",        0,   -1},
	{ XK_Up,            XK_ANY_MOD,             "\033OA",        0,   +1},
	{ XK_Down,          ShiftMask,              "\033[1;2B",     0,    0},
	{ XK_Down,          Mod1Mask,               "\033[1;3B",     0,    0},
	{ XK_Down,          ControlMask,            "\033[1;5B",     0,    0},
	{ XK_Down,          XK_ANY_MOD,             "\033[B",        0,   -1},
	{ XK_Down,          XK_ANY_MOD,             "\033OB",        0,   +1},
	{ XK_Left,          ShiftMask,              "\033[1;2D",     0,    0},
	{ XK_Left,          Mod1Mask,               "\033[1;3D",     0,    0},
	{ XK_Left,          ControlMask,            "\033[1;5D",     0,    0},
	{ XK_Left,          XK_ANY_MOD,             "\033[D",        0,   -1},
	{ XK_Left,          XK_ANY_MOD,             "\033OD",        0,   +1},
	{ XK_Right,         ShiftMask,              "\033[1;2C",     0,    0},
	{ XK_Right,         Mod1Mask,               "\033[1;3C",     0,    0},
	{ XK_Right,         ControlMask,            "\033[1;5C",     0,    0},
	{ XK_Right,         XK_ANY_MOD,             "\033[C",        0,   -1},
	{ XK_Right,         XK_ANY_MOD,             "\033OC",        0,   +1},
	{ XK_ISO_Left_Tab,  ShiftMask,              "\033[Z",        0,    0},
	{ XK_Return,        Mod1Mask,               "\033\r",        0,    0},
	{ XK_Return,        XK_ANY_MOD,             "\r",            0,    0},
	{ XK_Insert,        ShiftMask,              "\033[4l",      -1,    0},
	{ XK_Insert,        ShiftMask,              "\033[2;2~",    +1,    0},
	{ XK_Insert,        XK_ANY_MOD,             "\033[4h",      -1,    0},
	{ XK_Insert,        XK_ANY_MOD,             "\033[2~",      +1,    0},
	{ XK_Delete,        ShiftMask,              "\033[2K",      -1,    0},
	{ XK_Delete,        ShiftMask,              "\033[3;2~",    +1,    0},
	{ XK_Delete,        XK_ANY_MOD,             "\033[P",       -1,    0},
	{ XK_Delete,        XK_ANY_MOD,             "\033[3~",      +1,    0},
	{ XK_BackSpace,     XK_NO_MOD,              "\177",          0,    0},
	{ XK_BackSpace,     Mod1Mask,               "\033\177",      0,    0},
	{ XK_Home,          ShiftMask,              "\033[2J",       0,   -1},
	{ XK_Home,          ShiftMask,              "\033[1;2H",     0,   +1},
	{ XK_Home,          XK_ANY_MOD,             "\033[H",        0,   -1},
	{ XK_Home,          XK_ANY_MOD,             "\033[1~",       0,   +1},
	{ XK_End,           ShiftMask,              "\033[K",       -1,    0},
	{ XK_End,           ShiftMask,              "\033[1;2F",    +1,    0},
	{ XK_End,           XK_ANY_MOD,             "\033[4~",       0,    0},
	{ XK_Prior,         ShiftMask,              "\033[5;2~",     0,    0},
	{ XK_Prior,         XK_ANY_MOD,             "\033[5~",       0,    0},
	{ XK_Next,          ShiftMask,              "\033[6;2~",     0,    0},
	{ XK_Next,          XK_ANY_MOD,             "\033[6~",       0,    0},
	{ XK_F1,            XK_NO_MOD,              "\033OP",        0,    0},
	{ XK_F2,            XK_NO_MOD,              "\033OQ",        0,    0},
	{ XK_F3,            XK_NO_MOD,              "\033OR",        0,    0},
	{ XK_F4,            XK_NO_MOD,              "\033OS",        0,    0},
	{ XK_F5,            XK_NO_MOD,              "\033[15~",      0,    0},
	{ XK_F6,            XK_NO_MOD,              "\033[17~",      0,    0},
	{ XK_F7,            XK_NO_MOD,              "\033[18~",      0,    0},
	{ XK_F8,            XK_NO_MOD,              "\033[19~",      0,    0},
	{ XK_F9,            XK_NO_MOD,              "\033[20~",      0,    0},
	{ XK_F10,           XK_NO_MOD,              "\033[21~",      0,    0},
	{ XK_F11,           XK_NO_MOD,              "\033[23~",      0,    0},
	{ XK_F12,           XK_NO_MOD,              "\033[24~",      0,    0},
};

/* rectangular selection modifier (keyboard-driven) */
static uint selmasks[] = {
	[SEL_RECTANGULAR] = Mod1Mask,
};

/* printable ASCII, for single-wide advance estimation */
static char ascii_printable[] =
	" !\"#$%&'()*+,-./0123456789:;<=>?"
	"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
	"`abcdefghijklmnopqrstuvwxyz{|}~";
