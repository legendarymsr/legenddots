/* dwlb — minimal status bar for dwl. Tokyo Night, JetBrainsMono. Matches st/foot.
 * Launch it with dwl:  dwl -s dwlb   (dwlb reads dwl's status output). */

#define HEX_COLOR(hex)				\
	{ .red   = ((hex >> 24) & 0xff) * 257,	\
	  .green = ((hex >> 16) & 0xff) * 257,	\
	  .blue  = ((hex >> 8) & 0xff) * 257,	\
	  .alpha = (hex & 0xff) * 257 }

static bool ipc = false;
static bool hidden = false;
static bool bottom = false;
static bool hide_vacant = true;			// minimal: only show tags in use
static uint32_t vertical_padding = 2;
static bool status_commands = true;
static bool center_title = false;
static bool custom_title = false;
static bool active_color_title = true;
static uint32_t buffer_scale = 1;
static char *fontstr = "JetBrainsMono Nerd Font:size=11";
static char *tags_names[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

// Tokyo Night — selected tag = blue, occupied = dim, empty = comment grey
static pixman_color_t active_fg_color          = HEX_COLOR(0x1a1b26ff);
static pixman_color_t active_bg_color          = HEX_COLOR(0x7aa2f7ff);
static pixman_color_t occupied_fg_color        = HEX_COLOR(0xc0caf5ff);
static pixman_color_t occupied_bg_color        = HEX_COLOR(0x414868ff);
static pixman_color_t inactive_fg_color        = HEX_COLOR(0x565f89ff);
static pixman_color_t inactive_bg_color        = HEX_COLOR(0x1a1b26ff);
static pixman_color_t urgent_fg_color          = HEX_COLOR(0x1a1b26ff);
static pixman_color_t urgent_bg_color          = HEX_COLOR(0xf7768eff);
static pixman_color_t middle_bg_color          = HEX_COLOR(0x1a1b26ff);
static pixman_color_t middle_bg_color_selected = HEX_COLOR(0x414868ff);
