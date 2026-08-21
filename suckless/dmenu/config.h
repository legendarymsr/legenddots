/* dmenu — Tokyo Night. Build-time config for `dmenu-tokyonight` (guix/config.scm). */

static int topbar = 1;                       /* -b to make it appear at the bottom */
static const char *fonts[] = {
	"JetBrainsMono Nerd Font:size=11"
};
static const char *prompt = NULL;            /* -p to set at runtime */

static const char *colors[SchemeLast][2] = {
	/*               fg         bg       */
	[SchemeNorm] = { "#c0caf5", "#1a1b26" },
	[SchemeSel]  = { "#1a1b26", "#7aa2f7" },
	[SchemeOut]  = { "#1a1b26", "#9ece6a" },
};

static unsigned int lines = 0;               /* number of lines in vertical list */
static const char worddelimiters[] = " ";
