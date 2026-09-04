#define HEX_COLOR(h) {.red=((h>>24)&0xff)*257,.green=((h>>16)&0xff)*257,.blue=((h>>8)&0xff)*257,.alpha=(h&0xff)*257}
static bool ipc=false,hidden=false,bottom=false,hide_vacant=true,status_commands=true,center_title=false,custom_title=false,active_color_title=true;
static uint32_t vertical_padding=2,buffer_scale=1;
static char *fontstr="JetBrainsMono Nerd Font:size=11";
static char *tags_names[]={"1","2","3","4","5","6","7","8","9"};
static pixman_color_t active_fg_color=HEX_COLOR(0x1a1b26ff),active_bg_color=HEX_COLOR(0x7aa2f7ff),occupied_fg_color=HEX_COLOR(0xc0caf5ff),occupied_bg_color=HEX_COLOR(0x414868ff),inactive_fg_color=HEX_COLOR(0x565f89ff),inactive_bg_color=HEX_COLOR(0x1a1b26ff),urgent_fg_color=HEX_COLOR(0x1a1b26ff),urgent_bg_color=HEX_COLOR(0xf7768eff),middle_bg_color=HEX_COLOR(0x1a1b26ff),middle_bg_color_selected=HEX_COLOR(0x414868ff);
