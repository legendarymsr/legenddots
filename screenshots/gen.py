#!/usr/bin/env python3
"""
Mockup screenshots — each WM is visually distinct.
  Hyprland : Waybar, rounded windows, gaps, wallpaper visible
  i3       : Polybar + powerline, SHARP windows, title bars on every window
  Niri     : Waybar, rounded, column scroll aesthetic
  Ratpoison: bare 14px text bar, NO chrome on windows at all, 1px divider
Browsers:
  Brave    : Chromium-style chrome (shield icon, curved tabs)
  IceCat   : Firefox-style chrome (flat tabs, hamburger menu)
"""
from PIL import Image, ImageDraw, ImageFont
import os

# ── Tokyo Night Night ──────────────────────────────────────────────────────
BG     = "#1a1b2e"
BG2    = "#1f2335"
BG3    = "#24283b"
BG4    = "#292e42"
FG     = "#c0caf5"
FG2    = "#a9b1d6"
DIM    = "#565f89"
BORDER = "#3b4261"
ACCENT = "#7aa2f7"
GREEN  = "#9ece6a"
RED    = "#f7768e"
YELLOW = "#e0af68"
PURPLE = "#bb9af7"
CYAN   = "#7dcfff"
ORANGE = "#ff9e64"

# GitHub dark
GH_BG  = "#0d1117"
GH_BG2 = "#161b22"
GH_BG3 = "#21262d"
GH_FG  = "#e6edf3"
GH_FG2 = "#8b949e"
GH_LNK = "#58a6ff"
GH_BDR = "#30363d"

W, H = 1280, 720

MONO   = "/data/data/com.termux/files/home/.fonts/MononokiNerdFont-Bold.ttf"
MONO_R = "/data/data/com.termux/files/home/.fonts/GoMonoNerdFontMono-Regular.ttf"
SANS   = "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans.ttf"
SANS_B = "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
SANS_B = SANS_B if os.path.exists(SANS_B) else SANS

def fnt(path, size):
    try:    return ImageFont.truetype(path, size)
    except: return ImageFont.load_default()

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def tw(draw, text, font):
    bb = draw.textbbox((0,0), text, font=font)
    return bb[2] - bb[0]

def th_px(draw, text, font):
    bb = draw.textbbox((0,0), text, font=font)
    return bb[3] - bb[1]

# ── Wallpaper (dark Tokyo Night gradient) ──────────────────────────────────
def wallpaper(img, x, y, w, h):
    d = ImageDraw.Draw(img)
    for row in range(h):
        t = row / max(h, 1)
        r = int(0x16 + t * 0x08)
        g = int(0x17 + t * 0x05)
        b = int(0x2e + t * 0x08)
        d.line([x, y+row, x+w, y+row], fill=(r, g, b))

# ══════════════════════════════════════════════════════════════════════════
# WM bars
# ══════════════════════════════════════════════════════════════════════════

def waybar(d, fn, active=1, accent=ACCENT, right_txt="  CPU 6%   RAM 3.4G   12:34 "):
    """Hyprland / Niri waybar — rounded workspace pills."""
    BAR_H = 30
    d.rectangle([0, 0, W, BAR_H], fill=rgb(BG2))
    # workspace pills
    x = 10
    for i in range(1, 6):
        s = str(i)
        active_ws = (i == active)
        pill_w = 26
        fill = accent if active_ws else BG4
        d.rounded_rectangle([x, 5, x+pill_w, BAR_H-5], radius=5, fill=rgb(fill))
        label_col = BG if active_ws else DIM
        lw = tw(d, s, fn["bar"])
        d.text((x + (pill_w-lw)//2, 8), s, font=fn["bar"], fill=rgb(label_col))
        x += pill_w + 4
    # center: active window title
    title = "alacritty  —  zsh"
    lw = tw(d, title, fn["bar"])
    d.text(((W-lw)//2, 8), title, font=fn["bar"], fill=rgb(FG2))
    # right modules
    rw = tw(d, right_txt, fn["bar"])
    d.text((W-rw-6, 8), right_txt, font=fn["bar"], fill=rgb(FG2))
    return BAR_H

def polybar(d, fn, active=1, accent=YELLOW):
    """i3 polybar — powerline colour segments."""
    BAR_H = 24
    d.rectangle([0, 0, W, BAR_H], fill=rgb(BG))
    # workspaces: solid coloured blocks
    x = 0
    for i in range(1, 6):
        s = f"  {i}  "
        lw = tw(d, s, fn["bar_b"])
        active_ws = (i == active)
        fill = accent if active_ws else BG3
        d.rectangle([x, 0, x+lw, BAR_H], fill=rgb(fill))
        d.text((x, 5), s, font=fn["bar_b"],
               fill=rgb(BG if active_ws else DIM))
        x += lw
    # powerline arrow
    sep = "▌"
    sep_w = tw(d, sep, fn["pl"])
    d.text((x, 0), sep, font=fn["pl"], fill=rgb(BG3))
    x += sep_w
    # window title
    d.text((x+6, 5), "alacritty  —  zsh", font=fn["bar"], fill=rgb(FG2))
    # right modules
    mods = [
        ("  VOL 65%", DIM),
        ("  CPU 8% ", DIM),
        ("  MEM 4G ", DIM),
        (f"  12:34 ", accent),
    ]
    rx = W
    for txt, col in reversed(mods):
        rw = tw(d, txt, fn["bar"])
        rx -= rw
        seg_col = accent if col == accent else BG3
        d.rectangle([rx, 0, rx+rw, BAR_H], fill=rgb(seg_col))
        d.text((rx, 5), txt, font=fn["bar"],
               fill=rgb(BG if col == accent else FG2))
    return BAR_H

def ratpoison_bar(d, fn):
    """Ratpoison status bar — 14px plain text, completely minimal."""
    BAR_H = 14
    d.rectangle([0, 0, W, BAR_H], fill=rgb(BG3))
    d.text((4, 1), "ratpoison 1.4.9", font=fn["tiny"], fill=rgb(DIM))
    d.text((W-52, 1), "12:34", font=fn["tiny"], fill=rgb(FG2))
    return BAR_H

# ══════════════════════════════════════════════════════════════════════════
# Window frames
# ══════════════════════════════════════════════════════════════════════════

def hyprland_window(d, fn, x, y, w, h, title, accent):
    """Rounded corners, 2px coloured border, 24px title bar with traffic lights."""
    r = 10
    # border (drawn as outline)
    d.rounded_rectangle([x, y, x+w, y+h], radius=r,
                         outline=rgb(accent), width=2, fill=rgb(BG2))
    # title bar area
    TITLE_H = 24
    d.rounded_rectangle([x+2, y+2, x+w-2, y+TITLE_H+2], radius=r-1, fill=rgb(BG3))
    d.rectangle([x+2, y+TITLE_H//2, x+w-2, y+TITLE_H+2], fill=rgb(BG3))
    # traffic lights
    for ci, col in enumerate([RED, YELLOW, GREEN]):
        cx = x + 14 + ci*16
        d.ellipse([cx-5, y+7, cx+5, y+17], fill=rgb(col))
    # title text
    lw = tw(d, title, fn["title"])
    d.text((x + (w-lw)//2, y+6), title, font=fn["title"], fill=rgb(DIM))
    # content area (clear to BG)
    d.rectangle([x+2, y+TITLE_H+2, x+w-2, y+h-2], fill=rgb(BG))
    return x+4, y+TITLE_H+4, w-8, h-TITLE_H-6

def i3_window(d, fn, x, y, w, h, title, accent, active=True):
    """Sharp corners, solid 2px border, 22px title bar with title text."""
    TITLE_H = 22
    border_col = accent if active else BORDER
    # outer border
    d.rectangle([x, y, x+w, y+h], outline=rgb(border_col), width=2, fill=rgb(BG2))
    # title bar
    title_bg = BG3 if active else BG2
    d.rectangle([x+2, y+2, x+w-2, y+TITLE_H], fill=rgb(title_bg))
    # 3px accent line at top of title
    d.rectangle([x+2, y+2, x+w-2, y+4], fill=rgb(border_col))
    # title text centred
    lw = tw(d, title, fn["title"])
    d.text((x + (w-lw)//2, y+7), title, font=fn["title"],
           fill=rgb(FG2 if active else DIM))
    # content area
    d.rectangle([x+2, y+TITLE_H, x+w-2, y+h-2], fill=rgb(BG))
    return x+4, y+TITLE_H+2, w-8, h-TITLE_H-4

def ratpoison_window(d, x, y, w, h):
    """No chrome at all — content fills the rectangle."""
    d.rectangle([x, y, x+w, y+h], fill=rgb(BG))
    return x+2, y+2, w-4, h-4

# ══════════════════════════════════════════════════════════════════════════
# Terminal content — fastfetch + ls output
# ══════════════════════════════════════════════════════════════════════════

NIXOS_ART = [
    r"  \\  //  ",
    r"  _\\//_  ",
    r" /  \\/  \\ ",
    r"|   /  \   |",
    r" \  \\//  / ",
    r"  ¯\\/¯   ",
    r"  //  \\  ",
]
ARCH_ART = [
    r"      /\      ",
    r"     /  \     ",
    r"    / /\ \    ",
    r"   / /  \ \   ",
    r"  / / /\ \ \  ",
    r" /_/_/  \_\_\ ",
    r"              ",
]
GUIX_ART = [
    r"  _________  ",
    r" /  _______ \ ",
    r"| | GNU     | |",
    r"| | Guix    | |",
    r"| |_________| |",
    r" \_________/  ",
    r"              ",
]

LS_OUTPUT = [
    ("flake.nix",            GREEN),
    ("configuration.nix",    GREEN),
    ("home.nix",             GREEN),
    ("config.scm",           GREEN),
    ("alacritty.toml",       GREEN),
    ("home/",                CYAN),
    ("hyprland/",            CYAN),
    ("i3/",                  CYAN),
    ("niri/",                CYAN),
    ("screenshots/",         CYAN),
    ("README.md",            FG2),
    ("manifesto/",           CYAN),
]
COLOR_BLOCKS = [RED, GREEN, YELLOW, ACCENT, PURPLE, CYAN, FG2, DIM]

NIX_CODE = [
    ("{",                                                         FG),
    ('  description = "legenddots — NixOS flake";',              GREEN),
    ("",                                                          FG),
    ("  inputs = {",                                              FG),
    ("    nixpkgs.url =",                                         CYAN),
    ('      "github:nixos/nixpkgs/nixos-unstable";',             GREEN),
    ("    home-manager = {",                                      FG),
    ('      url = "github:nix-community/home-manager";',         GREEN),
    ('      inputs.nixpkgs.follows = "nixpkgs";',                GREEN),
    ("    };",                                                    FG),
    ('    nixvim.url = "github:nix-community/nixvim";',          GREEN),
    ("  };",                                                      FG),
    ("",                                                          FG),
    ("  outputs = { self, nixpkgs, home-manager, nixvim, ... }:", FG),
    ("  let",                                                     PURPLE),
    ('    system = "x86_64-linux";',                             GREEN),
    ("  in {",                                                    PURPLE),
    ("    nixosConfigurations.legend-box =",                      CYAN),
    ("      nixpkgs.lib.nixosSystem {",                           FG),
    ("        inherit system;",                                   CYAN),
    ("        modules = [",                                       FG),
    ("          ./system.nix",                                    GREEN),
    ("          home-manager.nixosModules.home-manager",          GREEN),
    ("          nixvim.nixosModules.nixvim",                      GREEN),
    ("        ];",                                                FG),
    ("      };",                                                  FG),
    ("  };",                                                      FG),
    ("}",                                                         FG),
]

def draw_nvim_pane(d, fn, x, y, w, h, filename="flake.nix", code=None, accent=ACCENT):
    """Neovim mockup with line numbers, syntax-coloured code, lualine statusbar."""
    if code is None:
        code = NIX_CODE
    LUALINE_H = 18
    LN_W = 34     # line-number column width

    # background
    d.rectangle([x, y, x+w, y+h], fill=rgb(BG))

    # lualine at bottom
    sl_y = y + h - LUALINE_H
    d.rectangle([x, sl_y, x+w, y+h], fill=rgb(BG3))
    # mode pill
    mode_txt = "  NORMAL  "
    mw = tw(d, mode_txt, fn["bar_b"])
    d.rectangle([x, sl_y, x+mw, y+h], fill=rgb(accent))
    d.text((x, sl_y+3), mode_txt, font=fn["bar_b"], fill=rgb(BG))
    # filename
    d.text((x+mw+8, sl_y+3), filename, font=fn["bar"], fill=rgb(FG2))
    # right: position
    pos = "  1:1   80% "
    pw = tw(d, pos, fn["bar"])
    d.rectangle([x+w-pw, sl_y, x+w, y+h], fill=rgb(accent))
    d.text((x+w-pw, sl_y+3), pos, font=fn["bar_b"], fill=rgb(BG))

    # code lines
    lh = 13
    cy2 = y + 4
    for i, (line, col) in enumerate(code):
        if cy2 + lh > sl_y - 2:
            break
        ln = str(i + 1).rjust(3)
        d.text((x+4, cy2), ln, font=fn["mono_r"], fill=rgb(DIM))
        d.text((x+LN_W, cy2), line, font=fn["mono_r"], fill=rgb(col))
        cy2 += lh

def draw_terminal(d, fn, cx, cy, cw, ch, os_name, wm, pkgs):
    art_map   = {"NixOS": (NIXOS_ART, ACCENT),
                 "GNU Guix": (GUIX_ART, GREEN),
                 "Arch Linux": (ARCH_ART, CYAN)}
    logo, col = art_map.get(os_name, (ARCH_ART, CYAN))

    lh = 14   # line height
    x, y = cx, cy

    # logo
    for line in logo:
        d.text((x, y), line, font=fn["mono_b"], fill=rgb(col))
        y += lh

    # info block (starts at same y as logo)
    ix = cx + 125
    iy = cy
    def iline(key, val, kc=CYAN, vc=FG):
        nonlocal iy
        d.text((ix,    iy), key, font=fn["mono_b"], fill=rgb(kc))
        d.text((ix+68, iy), val, font=fn["mono_r"], fill=rgb(vc))
        iy += lh

    d.text((ix, iy), "user@legend", font=fn["mono_b"], fill=rgb(col)); iy += lh
    d.text((ix, iy), "──────────────────", font=fn["mono_r"], fill=rgb(BORDER)); iy += lh
    iline("OS",     os_name)
    iline("Host",   "legend-box")
    iline("Kernel", "6.6.30-zen1")
    iline("WM",     wm)
    iline("Pkgs",   pkgs)
    iline("Shell",  "zsh 5.9")
    iline("Term",   "Alacritty")
    iline("Font",   "MononokiNF 12")
    iline("Theme",  "Tokyo Night")
    iy += 4
    for bi, bc in enumerate(COLOR_BLOCKS):
        bx = ix + bi*15
        d.rounded_rectangle([bx, iy, bx+11, iy+9], radius=2, fill=rgb(bc))
    iy += 18

    # cursor is at max(logo_end, info_end)
    iy = max(y, iy)

    # shell prompt + ls
    prompt = "user@legend"
    path   = " ~/legenddots"
    git    = " git:(master)"
    cur    = " ❯ "

    def draw_prompt(cmd=""):
        nonlocal iy
        px = cx
        d.text((px, iy), prompt, font=fn["mono_b"], fill=rgb(GREEN)); px += tw(d,prompt,fn["mono_b"])
        d.text((px, iy), path,   font=fn["mono_b"], fill=rgb(CYAN));  px += tw(d,path,  fn["mono_b"])
        d.text((px, iy), git,    font=fn["mono_b"], fill=rgb(PURPLE));px += tw(d,git,   fn["mono_b"])
        d.text((px, iy), cur,    font=fn["mono_b"], fill=rgb(FG2));   px += tw(d,cur,   fn["mono_b"])
        if cmd:
            d.text((px, iy), cmd, font=fn["mono_r"], fill=rgb(FG))
        iy += lh
        return px + tw(d, cur, fn["mono_b"])

    draw_prompt("ls")
    iy += 3

    # ls in 2 columns
    half = len(LS_OUTPUT) // 2 + len(LS_OUTPUT) % 2
    col_w = cw // 2
    for i in range(half):
        if iy > cy + ch - lh * 8:
            break
        name_l, fc_l = LS_OUTPUT[i]
        d.text((cx,        iy), name_l, font=fn["mono_r"], fill=rgb(fc_l))
        if i + half < len(LS_OUTPUT):
            name_r, fc_r = LS_OUTPUT[i + half]
            d.text((cx+col_w, iy), name_r, font=fn["mono_r"], fill=rgb(fc_r))
        iy += lh

    iy += 3
    cursor_x = draw_prompt()  # empty prompt with cursor
    d.rectangle([cursor_x, iy-lh+2, cursor_x+8, iy-2], fill=rgb(FG))
    iy += 4

    # ── tmux split line + neovim pane ─────────────────────────────────────
    remaining = (cy + ch) - iy
    if remaining > 60:
        TMUX_H = 16
        # tmux status bar
        d.rectangle([cx, iy, cx+cw, iy+TMUX_H], fill=rgb(BG3))
        d.rectangle([cx, iy, cx+60, iy+TMUX_H], fill=rgb(GREEN))
        d.text((cx+4, iy+2), "1:zsh", font=fn["tiny"], fill=rgb(BG))
        d.rectangle([cx+62, iy, cx+120, iy+TMUX_H], fill=rgb(BG4))
        d.text((cx+66, iy+2), "2:nvim", font=fn["tiny"], fill=rgb(FG2))
        d.text((cx+cw-80, iy+2), "legend-box  12:34", font=fn["tiny"], fill=rgb(DIM))
        iy += TMUX_H

        # neovim fills the rest
        draw_nvim_pane(d, fn, cx, iy, cw, cy+ch-iy, filename="flake.nix")

# ══════════════════════════════════════════════════════════════════════════
# Brave browser (Chromium-style)
# ══════════════════════════════════════════════════════════════════════════
BRAVE_CHR = "#1e2030"   # chrome bg
BRAVE_TAB = "#24283b"   # active tab
BRAVE_URL = "#292e42"   # url bar

def draw_brave(d, fn, x, y, w, h):
    # full chrome bg
    d.rectangle([x, y, x+w, y+h], fill=rgb(BRAVE_CHR))

    # ── tab bar (28px) ────────────────────────────────────────────────────
    TB_H = 28
    # inactive tab area bg
    d.rectangle([x, y, x+w, y+TB_H], fill=rgb(BRAVE_CHR))

    # active tab — Chrome-style: flat top, rounded bottom corners meeting bar
    tab_w = 210
    tx0, tx1 = x+6, x+6+tab_w
    ty0, ty1 = y+4, y+TB_H+2   # extends below bar boundary
    # draw the tab shape as a rounded-top rectangle
    d.rounded_rectangle([tx0, ty0, tx1, ty1], radius=6, fill=rgb(BRAVE_TAB))
    # flat bottom connector (overlap with the content area)
    d.rectangle([tx0, ty0+6, tx1, ty1], fill=rgb(BRAVE_TAB))

    # favicon (red circle = brave logo placeholder)
    d.ellipse([tx0+8, ty0+7, tx0+20, ty0+19], fill=rgb(ORANGE))
    # tab title
    d.text((tx0+26, ty0+8), "legendarymsr/legenddots", font=fn["sm"],
           fill=rgb(FG2))
    # close btn
    d.text((tx1-16, ty0+7), "×", font=fn["bar"], fill=rgb(DIM))
    # new tab + button
    d.text((tx1+8, y+8), "+", font=fn["bar"], fill=rgb(DIM))

    y += TB_H

    # ── navigation bar (34px) ─────────────────────────────────────────────
    NAV_H = 34
    d.rectangle([x, y, x+w, y+NAV_H], fill=rgb(BRAVE_CHR))
    # nav buttons: ← → ↺
    nx = x+8
    for sym, active in [("←", False), ("→", False), ("↺", True)]:
        col = FG2 if active else DIM
        d.text((nx, y+9), sym, font=fn["bar"], fill=rgb(col))
        nx += 22
    # url bar
    ux0, ux1 = x+76, x+w-90
    d.rounded_rectangle([ux0, y+6, ux1, y+NAV_H-6], radius=4,
                         fill=rgb(BRAVE_URL))
    d.text((ux0+10, y+11), "🔒  github.com/legendarymsr/legenddots",
           font=fn["url"], fill=rgb(FG2))
    # right icons: star bookmark, brave shield, extensions, menu
    ri = x+w-84
    for sym in ["☆", "🛡", "⊞", "⋮"]:
        d.text((ri, y+9), sym, font=fn["bar"], fill=rgb(DIM))
        ri += 20

    y += NAV_H
    # content area bg = GitHub dark
    d.rectangle([x, y, x+w, y+h], fill=rgb(GH_BG))
    return x, y, w, h - TB_H - NAV_H

# ══════════════════════════════════════════════════════════════════════════
# IceCat browser (Firefox-style)
# ══════════════════════════════════════════════════════════════════════════
ICAT_CHR = "#1c1b22"
ICAT_TAB = "#2a2831"
ICAT_URL = "#252329"

def draw_icecat(d, fn, x, y, w, h):
    d.rectangle([x, y, x+w, y+h], fill=rgb(ICAT_CHR))

    # ── tab bar (30px) — Firefox-style flat tabs ──────────────────────────
    TB_H = 30
    d.rectangle([x, y, x+w, y+TB_H], fill=rgb(ICAT_CHR))
    # Firefox-style: tab bar has a bottom border, tabs are more rectangular
    tab_w = 210
    tx0, tx1 = x+4, x+4+tab_w
    # active tab: slightly rounded top only, flat bottom
    d.rounded_rectangle([tx0, y+5, tx1, y+TB_H+1], radius=4, fill=rgb(ICAT_TAB))
    d.rectangle([tx0, y+TB_H-4, tx1, y+TB_H+1], fill=rgb(ICAT_TAB))
    # bright bottom line for active tab (Firefox Proton style)
    d.rectangle([tx0+2, y+TB_H-1, tx1-2, y+TB_H], fill=rgb(PURPLE))
    # favicon (icecat — purple gnu)
    d.ellipse([tx0+8, y+9, tx0+20, y+21], fill=rgb(PURPLE))
    d.text((tx0+26, y+10), "legendarymsr/legenddots", font=fn["sm"], fill=rgb(FG2))
    d.text((tx1-16, y+10), "×", font=fn["bar"], fill=rgb(DIM))
    # new tab button
    d.text((tx1+8, y+10), "+", font=fn["bar"], fill=rgb(DIM))
    # browser controls: on LEFT of tab bar (Firefox puts them differently)
    # actually Firefox has the tab bar above the toolbar

    y += TB_H

    # ── toolbar (32px) — Firefox puts URL bar in second row ───────────────
    TOOL_H = 32
    d.rectangle([x, y, x+w, y+TOOL_H], fill=rgb(ICAT_CHR))
    d.line([x, y, x+w, y], fill=rgb(BORDER))
    # nav buttons — smaller, on left
    nx = x+8
    for sym, en in [("←", False), ("→", False), ("↺", True)]:
        d.text((nx, y+8), sym, font=fn["bar"], fill=rgb(FG2 if en else DIM))
        nx += 20
    # URL bar — full width (Firefox style, wider than Chrome)
    ux0, ux1 = x+72, x+w-50
    d.rounded_rectangle([ux0, y+5, ux1, y+TOOL_H-5], radius=4,
                         fill=rgb(ICAT_URL), outline=rgb(PURPLE), width=1)
    d.text((ux0+10, y+10), "🔒  github.com/legendarymsr/legenddots",
           font=fn["url"], fill=rgb(FG2))
    # right: bookmarks, library, hamburger
    ri = x+w-44
    for sym in ["☆", "≡"]:
        d.text((ri, y+9), sym, font=fn["md"], fill=rgb(DIM))
        ri += 22

    y += TOOL_H
    d.rectangle([x, y, x+w, y+h], fill=rgb(GH_BG))
    return x, y, w, h - TB_H - TOOL_H

# ══════════════════════════════════════════════════════════════════════════
# Emacs EWW (text-mode web browser inside Emacs)
# ══════════════════════════════════════════════════════════════════════════
def draw_emacs_eww(d, fn, x, y, w, h):
    """Emacs frame: menu bar → EWW buffer → modeline → minibuffer."""
    d.rectangle([x, y, x+w, y+h], fill=rgb(BG))

    # ── menu bar (20px) ───────────────────────────────────────────────────
    MENU_H = 20
    d.rectangle([x, y, x+w, y+MENU_H], fill=rgb(BG3))
    d.line([x, y+MENU_H-1, x+w, y+MENU_H-1], fill=rgb(BORDER))
    menu_items = ["File", "Edit", "Options", "Buffers", "Tools", "Help"]
    mx = x + 6
    for item in menu_items:
        d.text((mx, y+4), item, font=fn["bar"], fill=rgb(FG2))
        mx += tw(d, item, fn["bar"]) + 14

    y += MENU_H

    # ── EWW buffer content ────────────────────────────────────────────────
    MODELINE_H = 18
    MINIBUF_H  = 16
    content_h  = h - MENU_H - MODELINE_H - MINIBUF_H
    py = y + 8
    px = x + 10
    lh = 14

    def eline(text, col=FG2, bold=False, indent=0):
        nonlocal py
        if py + lh > y + content_h:
            return
        f = fn["mono_b"] if bold else fn["mono_r"]
        d.text((px + indent, py), text, font=f, fill=rgb(col))
        py += lh

    def egap():
        nonlocal py
        py += lh // 2

    # EWW top: URL bar as a header line
    d.rectangle([x, y, x+w, y+lh+6], fill=rgb(BG2))
    d.text((px, y+3), "github.com/legendarymsr/legenddots",
           font=fn["mono_r"], fill=rgb(CYAN))
    py = y + lh + 10

    # page title
    eline("legendarymsr / legenddots", FG, bold=True)
    egap()

    # nav links (EWW renders links underlined, shown in accent colour)
    nav_items = ["[Code]", "[Issues]", "[Pull requests]", "[Actions]", "[Settings]"]
    nav_x = px
    for item in nav_items:
        if nav_x + tw(d, item, fn["mono_r"]) > x+w-10:
            break
        d.text((nav_x, py), item, font=fn["mono_r"], fill=rgb(ACCENT))
        iw = tw(d, item, fn["mono_r"])
        d.line([nav_x, py+lh-1, nav_x+iw, py+lh-1], fill=rgb(ACCENT))
        nav_x += iw + 8
    py += lh
    egap()

    # file list (EWW plain-text table)
    eline("── Files ─────────────────────────────────────────────", BORDER)
    for name, desc, age in [
        ("flake.nix",              "NixOS flake",             "3 days ago"),
        ("configuration.nix",      "NixOS stub",              "3 days ago"),
        ("home.nix",               "Home-manager entry",      "3 days ago"),
        ("home/",                  "packages, nixvim",        "3 days ago"),
        ("config.scm",             "Guix system config",      "1 day ago"),
        ("home-configuration.scm", "Guix home (ratpoison)",   "1 day ago"),
        ("alacritty.toml",         "Tokyo Night, 95% opacity","5 days ago"),
        ("hyprland/",              "Hyprland rice",           "2 days ago"),
        ("i3/",                    "i3 rice",                 "2 days ago"),
        ("niri/",                  "Niri rice",               "2 days ago"),
        ("screenshots/",           "Mockup screenshots",      "just now"),
        ("README.md",              "Expand explanations",     "just now"),
    ]:
        if py + lh > y + content_h - lh*6:
            break
        col = CYAN if name.endswith("/") else ACCENT
        d.text((px,        py), name, font=fn["mono_r"], fill=rgb(col))
        d.text((px+180,    py), desc, font=fn["mono_r"], fill=rgb(FG2))
        aw = tw(d, age, fn["mono_r"])
        d.text((x+w-aw-10, py), age,  font=fn["mono_r"], fill=rgb(DIM))
        py += lh
    egap()

    eline("── README.md ─────────────────────────────────────────", BORDER)
    eline("# legenddots", ACCENT, bold=True)
    eline("Personal dotfiles for NixOS, Guix, and Arch Linux.")
    eline("Theme: Tokyo Night throughout.")
    egap()
    eline("## NixOS", GREEN, bold=True)
    eline("Fully declarative. Hyprland, NixVim, home-manager.")
    egap()
    eline("## Guix", GREEN, bold=True)
    eline("Libre-only. Ratpoison, Emacs, Icecat, slock,")
    eline("AppArmor, nftables, fail2ban, hardened kernel.")
    egap()
    eline("## Arch Rice", GREEN, bold=True)
    eline("Niri · i3 · Hyprland. install.sh per rice.")

    # ── modeline ──────────────────────────────────────────────────────────
    ml_y = y + content_h
    d.rectangle([x, ml_y, x+w, ml_y+MODELINE_H], fill=rgb(BG3))
    d.rectangle([x, ml_y, x+w, ml_y+1], fill=rgb(BORDER))
    # left: mode indicators
    ml_left = " --:--  *eww*   All L1     (EWW)---"
    d.text((x+4, ml_y+3), ml_left, font=fn["mono_r"], fill=rgb(GREEN))
    # right: url
    ml_right = "github.com/legendarymsr/legenddots "
    rw = tw(d, ml_right, fn["mono_r"])
    d.text((x+w-rw, ml_y+3), ml_right, font=fn["mono_r"], fill=rgb(DIM))

    # ── minibuffer ────────────────────────────────────────────────────────
    mb_y = ml_y + MODELINE_H
    d.rectangle([x, mb_y, x+w, mb_y+MINIBUF_H], fill=rgb(BG))
    # blinking cursor in minibuffer
    d.rectangle([x+4, mb_y+3, x+10, mb_y+MINIBUF_H-3], fill=rgb(FG))

    return x, y, w, content_h

# ══════════════════════════════════════════════════════════════════════════
# GitHub dark page
# ══════════════════════════════════════════════════════════════════════════
FILES = [
    ("flake.nix",              "NixOS flake",            "3 days ago"),
    ("configuration.nix",      "NixOS stub",             "3 days ago"),
    ("home.nix",               "Home-manager entry",     "3 days ago"),
    ("home/",                  "packages, nixvim",       "3 days ago"),
    ("config.scm",             "Guix system config",     "1 day ago"),
    ("home-configuration.scm", "Guix home (ratpoison)",  "1 day ago"),
    ("alacritty.toml",         "Tokyo Night, 95% opacity","5 days ago"),
    ("hyprland/",              "Hyprland rice",          "2 days ago"),
    ("i3/",                    "i3 rice",                "2 days ago"),
    ("niri/",                  "Niri rice",              "2 days ago"),
    ("screenshots/",           "Mockup screenshots",     "just now"),
    ("README.md",              "Expand explanations",    "just now"),
]

def draw_github(d, fn, x, y, w, h):
    d.rectangle([x, y, x+w, y+h], fill=rgb(GH_BG))
    px, py = x+14, y+12

    # repo path
    d.text((px, py), "legendarymsr", font=fn["gh_sm"], fill=rgb(GH_LNK))
    ow = tw(d, "legendarymsr", fn["gh_sm"])
    d.text((px+ow, py), " / ", font=fn["gh_sm"], fill=rgb(GH_FG2))
    d.text((px+ow+14, py), "legenddots", font=fn["gh_lg"], fill=rgb(GH_FG))
    py += 22

    # badges
    for badge, bc in [("⭐ 0", YELLOW), ("MIT", GREEN), ("Tokyo Night", ACCENT)]:
        bw = tw(d, badge, fn["gh_sm"]) + 14
        d.rounded_rectangle([px, py, px+bw, py+16], radius=3,
                             fill=rgb(GH_BG3), outline=rgb(GH_BDR), width=1)
        d.text((px+7, py+2), badge, font=fn["gh_sm"], fill=rgb(bc))
        px += bw + 6
    px = x+14
    py += 22

    # tabs
    for i, tab in enumerate(["< > Code", "Issues", "Pull requests", "Actions", "Settings"]):
        tw_ = tw(d, tab, fn["gh_sm"])
        if i == 0:
            d.text((px, py), tab, font=fn["gh_sm"], fill=rgb(GH_FG))
            d.line([px, py+14, px+tw_, py+14], fill=rgb(ORANGE), width=2)
        else:
            d.text((px, py), tab, font=fn["gh_sm"], fill=rgb(GH_FG2))
        px += tw_ + 18
    py += 20
    px = x+14

    d.line([x, py, x+w, py], fill=rgb(GH_BDR))
    py += 8

    # branch bar
    d.rounded_rectangle([px, py, x+w-14, py+22], radius=4,
                         fill=rgb(GH_BG2), outline=rgb(GH_BDR), width=1)
    d.text((px+8, py+4), "⎇  master", font=fn["gh_sm"], fill=rgb(GH_FG2))
    msg = "legendarymsr: Redesign mockups with realistic WM layouts"
    d.text((px+90, py+4), msg, font=fn["gh_sm"], fill=rgb(GH_FG))
    d.text((x+w-68, py+4), "just now", font=fn["gh_sm"], fill=rgb(GH_FG2))
    py += 30

    # file list
    ROW_H = 20
    for name, desc, age in FILES:
        if py + ROW_H > y + h - 4:
            break
        d.line([x, py-1, x+w, py-1], fill=rgb(GH_BDR))
        icon = "📁" if name.endswith("/") else "📄"
        d.text((px, py+1), icon, font=fn["gh_sm"], fill=rgb(GH_FG2))
        d.text((px+18, py+1), name, font=fn["gh_sm"], fill=rgb(GH_LNK))
        d.text((px+200, py+1), desc, font=fn["gh_sm"], fill=rgb(GH_FG2))
        aw = tw(d, age, fn["gh_sm"])
        d.text((x+w-aw-14, py+1), age, font=fn["gh_sm"], fill=rgb(GH_FG2))
        py += ROW_H

    # README preview below file list
    if py + 30 < y + h:
        d.line([x, py, x+w, py], fill=rgb(GH_BDR))
        py += 10
        readme = [
            (ACCENT,  "# legenddots"),
            (GH_FG2,  ""),
            (GH_FG,   "Personal dotfiles for NixOS, Guix, and Arch Linux. Theme: Tokyo Night throughout."),
            (GH_FG2,  ""),
            (YELLOW,  "## Screenshots"),
            (GH_FG2,  ""),
            (GREEN,   "## NixOS"),
            (GH_FG,   "Fully declarative desktop — packages, services, users, Neovim config all in Nix."),
            (GH_FG,   "Nothing installed imperatively. WM: Hyprland. Editor: NixVim. Shell: Zsh + starship."),
            (GH_FG2,  ""),
            (GREEN,   "## Guix"),
            (GH_FG,   "Libre software only. GNU Guix enforces no proprietary blobs by policy."),
            (GH_FG,   "WM: Ratpoison (prefix-key, tmux-like). Editor: Emacs. Browser: IceCat."),
            (GH_FG,   "Hardened kernel, AppArmor, nftables, fail2ban, noexec mounts."),
            (GH_FG2,  ""),
            (GREEN,   "## Arch Rice"),
            (GH_FG,   "Three self-contained rices — Niri (scrollable Wayland), i3 (X11), Hyprland (Wayland)."),
            (GH_FG,   "Each has an install.sh that symlinks configs and backs up existing ones."),
            (GH_FG2,  ""),
            (YELLOW,  "## Keybinds"),
            (GH_FG2,  "Arch rices use Mod (Super). Ratpoison uses a prefix key C-t like Tmux."),
            (GH_FG2,  ""),
            (GH_FG2,  "| Action          | Arch (Mod+)   | Guix (C-t then) |"),
            (GH_BDR,  "|-----------------|---------------|-----------------|"),
            (GH_FG2,  "| Terminal        | Return        | c               |"),
            (GH_FG2,  "| Launcher        | d             | d               |"),
            (GH_FG2,  "| Browser         | b             | b               |"),
            (GH_FG2,  "| Close window    | Shift+q       | q               |"),
            (GH_FG2,  "| Exit            | q             | Q               |"),
            (GH_FG2,  "| Focus           | h/j/k/l       | h/j/k/l         |"),
            (GH_FG2,  "| Workspace       | 1-9           | 1-9             |"),
        ]
        for rc, rl in readme:
            if py + 13 > y + h:
                break
            d.text((px, py), rl, font=fn["gh_sm"], fill=rgb(rc))
            py += 13

# ══════════════════════════════════════════════════════════════════════════
# Font registry
# ══════════════════════════════════════════════════════════════════════════
def make_fonts():
    return {
        "bar":    fnt(SANS,   11),
        "bar_b":  fnt(SANS_B, 11),
        "pl":     fnt(SANS_B, 18),   # powerline separators
        "title":  fnt(SANS,   10),
        "tiny":   fnt(SANS,   9),
        "sm":     fnt(SANS,   10),
        "md":     fnt(SANS,   13),
        "lg":     fnt(SANS_B, 14),
        "url":    fnt(SANS,   10),
        "mono_b": fnt(MONO,   12),
        "mono_r": fnt(MONO_R, 12),
        "gh_sm":  fnt(SANS,   11),
        "gh_md":  fnt(SANS,   12),
        "gh_lg":  fnt(SANS_B, 14),
    }

# ══════════════════════════════════════════════════════════════════════════
# Per-WM image generators
# ══════════════════════════════════════════════════════════════════════════

GAP   = 8
TW    = 490  # terminal window width

def gen_hyprland(outpath, os_name, accent, pkgs, browser_fn):
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = make_fonts()

    bar_h = waybar(d, fn, accent=accent)
    wallpaper(img, 0, bar_h, W, H-bar_h)

    # terminal window
    tx, ty = GAP, bar_h+GAP
    tw_, th = TW, H-bar_h-GAP*2
    cx, cy, cw, ch = hyprland_window(d, fn, tx, ty, tw_, th,
                                      "alacritty  —  zsh", accent)
    draw_terminal(d, fn, cx+2, cy+2, cw-4, ch-4, os_name, "Hyprland", pkgs)

    # browser window
    bx = GAP*2+TW
    bw = W-bx-GAP
    hyprland_window(d, fn, bx, ty, bw, th, "Brave", accent, )
    pcx, pcy, pcw, pch = browser_fn(d, fn, bx+2, ty+2, bw-4, th-4)
    draw_github(d, fn, pcx, pcy, pcw, pch)

    img.save(outpath)
    print(f"  {outpath}")


def gen_i3(outpath, os_name, accent, pkgs):
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = make_fonts()

    # polybar
    bar_h = polybar(d, fn, accent=accent)
    wallpaper(img, 0, bar_h, W, H-bar_h)

    SMALL_GAP = 4
    tx, ty = SMALL_GAP, bar_h+SMALL_GAP
    tw_, th = TW+GAP, H-bar_h-SMALL_GAP*2

    # terminal window — sharp
    cx, cy, cw, ch = i3_window(d, fn, tx, ty, tw_, th,
                                "alacritty  —  zsh", accent, active=True)
    draw_terminal(d, fn, cx+2, cy+2, cw-4, ch-4, os_name, "i3", pkgs)

    # browser window — sharp
    bx = SMALL_GAP*2+TW+GAP
    bw = W-bx-SMALL_GAP
    bh = th
    cx2, cy2, cw2, ch2 = i3_window(d, fn, bx, ty, bw, bh,
                                    "Brave  —  github.com", accent, active=False)
    pcx, pcy, pcw, pch = draw_brave(d, fn, cx2, cy2, cw2, ch2)
    draw_github(d, fn, pcx, pcy, pcw, pch)

    img.save(outpath)
    print(f"  {outpath}")


def gen_niri(outpath, os_name, accent, pkgs):
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = make_fonts()

    bar_h = waybar(d, fn, accent=accent,
                   right_txt="  Niri   CPU 4%   RAM 2.9G   12:34 ")
    wallpaper(img, 0, bar_h, W, H-bar_h)

    # Niri: column layout hint — show arrow on right edge
    tx, ty = GAP, bar_h+GAP
    tw_, th = TW, H-bar_h-GAP*2
    cx, cy, cw, ch = hyprland_window(d, fn, tx, ty, tw_, th,
                                      "alacritty  —  zsh", accent)
    draw_terminal(d, fn, cx+2, cy+2, cw-4, ch-4, os_name, "Niri", pkgs)

    bx = GAP*2+TW
    bw = W-bx-GAP
    # scroll indicator — subtle arrow hinting at more columns →
    d.text((W-20, H//2-10), "›", font=fnt(SANS_B, 28), fill=rgb(DIM))
    hyprland_window(d, fn, bx, ty, bw-24, th, "Brave", accent)
    pcx, pcy, pcw, pch = draw_brave(d, fn, bx+2, ty+2, bw-28, th-4)
    draw_github(d, fn, pcx, pcy, pcw, pch)

    img.save(outpath)
    print(f"  {outpath}")


def gen_ratpoison(outpath, os_name, pkgs):
    """Ratpoison: no WM chrome whatsoever. Windows are raw rectangles."""
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = make_fonts()

    bar_h = ratpoison_bar(d, fn)

    # two windows split 50/50, no gaps, no borders
    split = W // 2
    # left — terminal
    lx, ly, lw, lh = ratpoison_window(d, 0, bar_h, split, H-bar_h)
    draw_terminal(d, fn, lx, ly, lw, lh, os_name, "Ratpoison", pkgs)

    # 1px divider
    d.line([split, bar_h, split, H], fill=rgb(BORDER))

    # right — emacs eww (no window frame, just emacs directly)
    rx, ry, rw, rh = ratpoison_window(d, split+1, bar_h, W-split-1, H-bar_h)
    draw_emacs_eww(d, fn, rx, ry, rw, rh)

    img.save(outpath)
    print(f"  {outpath}")


# ══════════════════════════════════════════════════════════════════════════
out = os.path.dirname(os.path.abspath(__file__))

print("Generating...")
gen_hyprland(f"{out}/nixos-hyprland.png",  "NixOS",      ACCENT, "1842 (nix)",    draw_brave)
gen_ratpoison(f"{out}/guix-ratpoison.png", "GNU Guix",             "312 (guix)")
gen_niri(f"{out}/arch-niri.png",           "Arch Linux", PURPLE, "1203 (pacman)")
gen_i3(f"{out}/arch-i3.png",              "Arch Linux", YELLOW, "1187 (pacman)")
gen_hyprland(f"{out}/arch-hyprland.png",  "Arch Linux", RED,    "1241 (pacman)", draw_brave)
print("done.")
