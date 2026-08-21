/* slock — Tokyo Night. Build-time config for `slock-tokyonight` (guix/config.scm). */

/* drop privileges to this user/group after locking */
static const char *user  = "nobody";
static const char *group = "nogroup";

static const char *colorname[NUMCOLS] = {
	[INIT] =   "#1a1b26",   /* after initialization (idle) */
	[INPUT] =  "#7aa2f7",   /* during input                */
	[FAILED] = "#f7768e",   /* wrong password              */
};

/* treat a cleared input like a wrong password (color) */
static const int failonclear = 1;
