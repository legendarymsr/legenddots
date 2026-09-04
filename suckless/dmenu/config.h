static int topbar = 1;
static const char *fonts[] = {
 "JetBrainsMono Nerd Font:size=11"
};
static const char *prompt = NULL;
static const char *colors[SchemeLast][2] = {
 [SchemeNorm] = { "#c0caf5", "#1a1b26" },
 [SchemeSel] = { "#1a1b26", "#7aa2f7" },
 [SchemeOut] = { "#1a1b26", "#9ece6a" },
};
static unsigned int lines = 0;
static const char worddelimiters[] = " ";
