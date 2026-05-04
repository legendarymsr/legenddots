#!/usr/bin/env python3
"""Mockup screenshot generator — realistic WM + browser tiles."""
from PIL import Image, ImageDraw, ImageFont
import os

# ── Tokyo Night Storm palette ──────────────────────────────────────────────
BG       = "#1a1b2e"
BG2      = "#1f2335"
BG3      = "#24283b"
BG4      = "#292e42"
FG       = "#c0caf5"
FG2      = "#a9b1d6"
DIM      = "#565f89"
BORDER   = "#3b4261"
ACCENT   = "#7aa2f7"
GREEN    = "#9ece6a"
RED      = "#f7768e"
YELLOW   = "#e0af68"
PURPLE   = "#bb9af7"
CYAN     = "#7dcfff"
ORANGE   = "#ff9e64"
WHITE    = "#cdd6f4"

# GitHub dark palette
GH_BG    = "#0d1117"
GH_BG2   = "#161b22"
GH_BG3   = "#21262d"
GH_FG    = "#e6edf3"
GH_FG2   = "#8b949e"
GH_LINK  = "#58a6ff"
GH_GREEN = "#3fb950"
GH_BORDER= "#30363d"

MONO  = "/data/data/com.termux/files/home/.fonts/MononokiNerdFont-Bold.ttf"
MONO_R= "/data/data/com.termux/files/home/.fonts/GoMonoNerdFontMono-Regular.ttf"
SANS  = "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans.ttf"
SANS_B= "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
SANS_B= SANS_B if os.path.exists(SANS_B) else SANS

def f(path, size):
    try:    return ImageFont.truetype(path, size)
    except: return ImageFont.load_default()

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def text_w(draw, text, font):
    bb = draw.textbbox((0,0), text, font=font)
    return bb[2] - bb[0]

W, H = 1280, 720
GAP  = 8     # window gaps
TERM_W = 510 # terminal pane width

# ── font sizes ─────────────────────────────────────────────────────────────
def fonts():
    return {
        "bar":    f(SANS,   11),
        "bar_b":  f(SANS_B, 11),
        "title":  f(SANS,   11),
        "mono":   f(MONO_R, 12),
        "mono_b": f(MONO,   12),
        "url":    f(SANS,   11),
        "sm":     f(SANS,   10),
        "md":     f(SANS,   13),
        "lg":     f(SANS_B, 15),
        "xl":     f(SANS_B, 18),
        "gh_sm":  f(SANS,   11),
        "gh_md":  f(SANS,   13),
        "gh_lg":  f(SANS_B, 16),
        "gh_xl":  f(SANS_B, 20),
    }

# ── ASCII logos ────────────────────────────────────────────────────────────
NIXOS_LOGO = [
    r"  \\  //  ",
    r"  _\\//_  ",
    r" (_    _) ",
    r"  _//\\_  ",
    r"  //  \\  ",
    r"          ",
]
ARCH_LOGO = [
    r"     /\     ",
    r"    /  \    ",
    r"   / /\ \   ",
    r"  / /  \ \  ",
    r" /_/    \_\ ",
    r"             ",
]
GUIX_LOGO = [
    r" _________ ",
    r"|  _______ |",
    r"| |  Guix | |",
    r"| |_______| |",
    r"|___________|",
    r"             ",
]

LOGOS = {
    "NixOS":      (NIXOS_LOGO, ACCENT),
    "Arch Linux": (ARCH_LOGO,  CYAN),
    "GNU Guix":   (GUIX_LOGO,  GREEN),
}

COLOR_BLOCKS = [RED, GREEN, YELLOW, ACCENT, PURPLE, CYAN, FG2, DIM]

# ── Waybar ─────────────────────────────────────────────────────────────────
def draw_waybar(d, fn, y, h, active_ws, wm_color, right="  12:34  2026-05-05 "):
    d.rectangle([0, y, W-1, y+h-1], fill=rgb(BG2))
    # workspaces
    wx = 8
    for i in range(1, 6):
        ws_str = str(i)
        active = (i == active_ws)
        bw = 22
        bg = wm_color if active else BG4
        d.rounded_rectangle([wx, y+4, wx+bw, y+h-4], radius=4, fill=rgb(bg))
        tw = text_w(d, ws_str, fn["bar"])
        d.text((wx + (bw-tw)//2, y+5), ws_str, font=fn["bar"],
               fill=rgb(BG if active else DIM))
        wx += bw + 3
    # center title
    title = "alacritty — fastfetch"
    tw = text_w(d, title, fn["bar"])
    d.text(((W-tw)//2, y+5), title, font=fn["bar"], fill=rgb(FG2))
    # right modules
    rw = text_w(d, right, fn["bar"])
    d.text((W-rw-4, y+5), right, font=fn["bar"], fill=rgb(FG2))

# ── Polybar ────────────────────────────────────────────────────────────────
def draw_polybar(d, fn, y, h, active_ws, wm_color):
    d.rectangle([0, y, W-1, y+h-1], fill=rgb(BG))
    # powerline workspace
    wx = 0
    SEP = "▌"
    for i in range(1, 6):
        active = (i == active_ws)
        bg = wm_color if active else BG3
        ws_str = f"  {i}  "
        tw = text_w(d, ws_str, fn["bar_b"])
        d.rectangle([wx, y, wx+tw, y+h], fill=rgb(bg))
        d.text((wx, y+4), ws_str, font=fn["bar_b"],
               fill=rgb(BG if active else DIM))
        wx += tw
    # sep arrow
    d.text((wx, y+3), SEP, font=f(SANS, 18), fill=rgb(BG3))
    # right side
    right_items = [
        ("  CPU 8%", FG2), ("  MEM 4.1G", FG2), ("  Vol 65%", FG2),
        (f"   12:34", wm_color),
    ]
    rx = W
    for txt, col in reversed(right_items):
        tw = text_w(d, txt, fn["bar"])
        rx -= tw + 6
        d.text((rx, y+5), txt, font=fn["bar"], fill=rgb(col))

# ── Window chrome (title bar + border) ─────────────────────────────────────
def draw_window(d, fn, x, y, w, h, title, border_col, rounded=True, titled=True):
    r = 8 if rounded else 0
    # border glow
    d.rounded_rectangle([x-1, y-1, x+w, y+h], radius=r+1,
                         outline=rgb(border_col), width=2)
    d.rounded_rectangle([x, y, x+w-1, y+h-1], radius=r, fill=rgb(BG2))
    if titled:
        title_h = 26
        d.rounded_rectangle([x, y, x+w-1, y+title_h], radius=r, fill=rgb(BG3))
        if rounded:
            d.rectangle([x, y+r, x+w-1, y+title_h], fill=rgb(BG3))
        # traffic lights
        for ci, col in enumerate([RED, YELLOW, GREEN]):
            cx = x + 10 + ci*16
            d.ellipse([cx-4, y+9, cx+4, y+17], fill=rgb(col))
        tw = text_w(d, title, fn["title"])
        d.text((x + (w-tw)//2, y+7), title, font=fn["title"], fill=rgb(DIM))
    return (x, y + (26 if titled else 0), w, h - (26 if titled else 0))

# ── Fastfetch terminal content ─────────────────────────────────────────────
def draw_fastfetch(d, fn, cx, cy, cw, ch, os_name, wm, pkgs):
    logo_lines, logo_col = LOGOS.get(os_name, (ARCH_LOGO, CYAN))
    lh = 15
    lx, ly = cx + 8, cy + 8
    for line in logo_lines:
        d.text((lx, ly), line, font=fn["mono_b"], fill=rgb(logo_col))
        ly += lh

    ix = cx + 120
    iy = cy + 8
    lh2 = 15

    user = "user@legend"
    tw = text_w(d, user, fn["mono_b"])
    d.text((ix, iy), user, font=fn["mono_b"], fill=rgb(logo_col))
    iy += lh2
    sep = "─" * (tw // 8)
    d.text((ix, iy), sep, font=fn["mono"], fill=rgb(BORDER))
    iy += lh2

    info = [
        ("OS",      os_name,        FG),
        ("Host",    "legend-box",   FG),
        ("Kernel",  "6.6.30-zen1",  FG),
        ("WM",      wm,             FG),
        ("Pkgs",    pkgs,           FG),
        ("Shell",   "zsh 5.9",      FG),
        ("Term",    "Alacritty",    FG),
        ("Font",    "MononokiNF",   FG),
        ("Theme",   "Tokyo Night",  FG),
    ]
    for key, val, vcol in info:
        d.text((ix, iy),      key, font=fn["mono_b"], fill=rgb(CYAN))
        d.text((ix+70, iy),   val, font=fn["mono"],   fill=rgb(vcol))
        iy += lh2

    iy += 5
    for bi, col in enumerate(COLOR_BLOCKS):
        bx = ix + bi*16
        d.rounded_rectangle([bx, iy, bx+12, iy+10], radius=2, fill=rgb(col))

# ── Brave browser chrome ───────────────────────────────────────────────────
BRAVE_BG     = "#1e2030"
BRAVE_TAB_A  = "#24283b"
BRAVE_TAB_I  = "#1a1b2e"
BRAVE_BAR    = "#1e2030"
BRAVE_URL    = "#292e42"

def draw_brave(d, fn, x, y, w, h, url="github.com/legendarymsr/legenddots"):
    # chrome bg
    d.rectangle([x, y, x+w-1, y+h-1], fill=rgb(BRAVE_BG))
    # tab bar
    tab_h = 28
    d.rectangle([x, y, x+w-1, y+tab_h], fill=rgb(BRAVE_TAB_I))
    # active tab
    tab_w = 220
    d.rounded_rectangle([x+6, y+5, x+6+tab_w, y+tab_h], radius=5,
                         fill=rgb(BRAVE_TAB_A))
    d.ellipse([x+14, y+10, x+22, y+18], fill=rgb(RED))  # favicon
    d.text((x+27, y+9), "legendarymsr/legenddots", font=fn["sm"],
           fill=rgb(FG2))
    # close btn
    d.text((x+6+tab_w-14, y+9), "×", font=fn["bar"], fill=rgb(DIM))

    # toolbar
    tool_y = y + tab_h
    tool_h = 36
    d.rectangle([x, tool_y, x+w-1, tool_y+tool_h], fill=rgb(BRAVE_BAR))
    # nav buttons
    for bi, sym in enumerate(["←", "→", "↺"]):
        d.text((x+8+bi*22, tool_y+9), sym, font=fn["bar"],
               fill=rgb(DIM if bi < 2 else FG2))
    # url bar
    ux0, ux1 = x+76, x+w-80
    d.rounded_rectangle([ux0, tool_y+6, ux1, tool_y+tool_h-6], radius=4,
                         fill=rgb(BRAVE_URL))
    # lock icon + url
    d.text((ux0+8, tool_y+11), "🔒", font=fn["sm"], fill=rgb(GREEN))
    d.text((ux0+26, tool_y+11), url, font=fn["url"], fill=rgb(FG2))
    # brave shield icon
    d.text((x+w-72, tool_y+9), "🦁", font=fn["sm"], fill=rgb(ORANGE))
    # extensions + menu
    d.text((x+w-48, tool_y+9), "⋮", font=fn["md"], fill=rgb(DIM))

    return (x, tool_y+tool_h, w, h - tab_h - tool_h)

# ── Icecat browser chrome ──────────────────────────────────────────────────
ICAT_BG  = "#1c1b22"
ICAT_TAB = "#2a2831"
ICAT_URL = "#252329"

def draw_icecat(d, fn, x, y, w, h, url="github.com/legendarymsr/legenddots"):
    d.rectangle([x, y, x+w-1, y+h-1], fill=rgb(ICAT_BG))
    # tab bar
    tab_h = 30
    d.rectangle([x, y, x+w-1, y+tab_h], fill=rgb(ICAT_BG))
    tab_w = 220
    d.rounded_rectangle([x+4, y+6, x+4+tab_w, y+tab_h+1], radius=6,
                         fill=rgb(ICAT_TAB))
    d.ellipse([x+12, y+12, x+22, y+22], fill=rgb(PURPLE))  # icecat favicon
    d.text((x+27, y+11), "legendarymsr/legenddots", font=fn["sm"],
           fill=rgb(FG2))
    d.text((x+4+tab_w-14, y+11), "×", font=fn["bar"], fill=rgb(DIM))

    # toolbar
    tool_y = y + tab_h
    tool_h = 34
    d.rectangle([x, tool_y, x+w-1, tool_y+tool_h], fill=rgb(ICAT_BG))
    d.line([x, tool_y+tool_h-1, x+w-1, tool_y+tool_h-1], fill=rgb(BORDER))
    for bi, sym in enumerate(["←", "→", "↺"]):
        d.text((x+8+bi*22, tool_y+8), sym, font=fn["bar"],
               fill=rgb(DIM if bi < 2 else FG2))
    ux0, ux1 = x+76, x+w-70
    d.rounded_rectangle([ux0, tool_y+5, ux1, tool_y+tool_h-5], radius=4,
                         fill=rgb(ICAT_URL))
    d.text((ux0+8, tool_y+10), "🔒", font=fn["sm"], fill=rgb(GREEN))
    d.text((ux0+26, tool_y+10), url, font=fn["url"], fill=rgb(FG2))
    d.text((x+w-50, tool_y+8), "☰", font=fn["md"], fill=rgb(DIM))

    return (x, tool_y+tool_h, w, h - tab_h - tool_h)

# ── GitHub dark page content ───────────────────────────────────────────────
FILES = [
    ("📄", "flake.nix",              "NixOS flake entry",            "3 days ago"),
    ("📄", "configuration.nix",      "NixOS stub",                   "3 days ago"),
    ("📄", "home.nix",               "Home-manager entry",           "3 days ago"),
    ("📁", "home/",                  "packages, nixvim",             "3 days ago"),
    ("📄", "config.scm",             "Guix system config",           "1 day ago"),
    ("📄", "home-configuration.scm", "Guix home (ratpoison, emacs)", "1 day ago"),
    ("📄", "alacritty.toml",         "Tokyo Night, 95% opacity",     "5 days ago"),
    ("📁", "hyprland/",              "Hyprland rice",                "2 days ago"),
    ("📁", "i3/",                    "i3 rice",                      "2 days ago"),
    ("📁", "niri/",                  "Niri rice",                    "2 days ago"),
    ("📁", "screenshots/",           "Mockup screenshots",           "just now"),
    ("📄", "README.md",              "Expand explanations",          "just now"),
]

def draw_github_page(d, fn, x, y, w, h):
    # page bg
    d.rectangle([x, y, x+w-1, y+h-1], fill=rgb(GH_BG))
    px, py = x+12, y+10

    # repo header
    d.text((px, py), "legendarymsr", font=fn["gh_sm"], fill=rgb(GH_LINK))
    tw = text_w(d, "legendarymsr", fn["gh_sm"])
    d.text((px+tw, py), " / legenddots", font=fn["gh_lg"], fill=rgb(GH_FG))
    py += 24

    # badges
    for badge, col in [("⭐ 0", YELLOW), ("MIT", GREEN), ("Tokyo Night", ACCENT)]:
        bw = text_w(d, badge, fn["gh_sm"]) + 12
        d.rounded_rectangle([px, py, px+bw, py+16], radius=3,
                             fill=rgb(GH_BG3), outline=rgb(GH_BORDER), width=1)
        d.text((px+6, py+2), badge, font=fn["gh_sm"], fill=rgb(col))
        px += bw + 6
    px = x+12
    py += 22

    # tabs (Code / Issues / PRs …)
    tabs = ["< > Code", "Issues", "Pull requests", "Actions"]
    for i, tab in enumerate(tabs):
        tw = text_w(d, tab, fn["gh_sm"])
        if i == 0:
            d.text((px, py), tab, font=fn["gh_sm"], fill=rgb(GH_FG))
            d.line([px, py+14, px+tw, py+14], fill=rgb(ORANGE), width=2)
        else:
            d.text((px, py), tab, font=fn["gh_sm"], fill=rgb(GH_FG2))
        px += tw + 18
    py += 22
    px = x+12

    # divider
    d.line([x, py, x+w, py], fill=rgb(GH_BORDER))
    py += 8

    # branch info bar
    d.rounded_rectangle([px, py, x+w-12, py+22], radius=4,
                         fill=rgb(GH_BG2), outline=rgb(GH_BORDER), width=1)
    d.text((px+8, py+4), "⎇  master", font=fn["gh_sm"], fill=rgb(GH_FG2))
    d.text((px+90, py+4), "legendarymsr: Expand README with mockup screenshots",
           font=fn["gh_sm"], fill=rgb(GH_FG))
    d.text((x+w-60, py+4), "just now", font=fn["gh_sm"], fill=rgb(GH_FG2))
    py += 28

    # file list
    row_h = 20
    for icon, name, desc, age in FILES:
        if py + row_h > y+h-8:
            break
        # row bg alternating subtle
        d.rectangle([x, py-2, x+w-1, py+row_h-2], fill=rgb(GH_BG))
        d.line([x, py+row_h-2, x+w, py+row_h-2], fill=rgb(GH_BORDER))
        # icon + name
        d.text((px, py), icon, font=fn["gh_sm"], fill=rgb(GH_FG2))
        d.text((px+18, py), name, font=fn["gh_sm"], fill=rgb(GH_LINK))
        # description (truncated)
        desc_x = px + 200
        d.text((desc_x, py), desc, font=fn["gh_sm"], fill=rgb(GH_FG2))
        # age right-aligned
        aw = text_w(d, age, fn["gh_sm"])
        d.text((x+w-aw-12, py), age, font=fn["gh_sm"], fill=rgb(GH_FG2))
        py += row_h

# ── Wallpaper (minimal dark gradient) ─────────────────────────────────────
def draw_wallpaper(d, x, y, w, h):
    for row in range(h):
        t = row / h
        r = int(26 + t*8)
        g = int(27 + t*8)
        b = int(46 + t*8)
        d.line([x, y+row, x+w, y+row], fill=(r, g, b))

# ══════════════════════════════════════════════════════════════════════════
# Per-WM generators
# ══════════════════════════════════════════════════════════════════════════

def gen_hyprland(path, os_name, wm_color, pkgs, browser_fn):
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = fonts()

    bar_h = 28
    draw_waybar(d, fn, 0, bar_h, 1, wm_color,
                right=f"  CPU 6%  RAM 3.4G  12:34  2026-05-05 ")

    # desktop wallpaper strip below bar
    draw_wallpaper(d, 0, bar_h, W, H-bar_h)

    # terminal window
    tx = GAP
    ty = bar_h + GAP
    tw = TERM_W
    th = H - bar_h - GAP*2
    cx, cy, cw, ch = draw_window(d, fn, tx, ty, tw, th,
                                 "alacritty  —  zsh", wm_color, rounded=True)
    d.rectangle([cx, cy, cx+cw-1, cy+ch-1], fill=rgb(BG))
    draw_fastfetch(d, fn, cx+4, cy+4, cw-8, ch-8, os_name, "Hyprland", pkgs)

    # browser window
    bx = GAP*2 + TERM_W
    by = bar_h + GAP
    bw = W - bx - GAP
    bh = H - bar_h - GAP*2
    draw_window(d, fn, bx, by, bw, bh, "Brave", wm_color, rounded=True, titled=False)
    pcx, pcy, pcw, pch = browser_fn(d, fn, bx+1, by+1, bw-2, bh-2)
    draw_github_page(d, fn, pcx, pcy, pcw, pch)

    img.save(path)
    print(f"  {path}")


def gen_i3(path, os_name, wm_color, pkgs):
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = fonts()

    bar_h = 24
    draw_polybar(d, fn, 0, bar_h, 1, wm_color)

    # i3 windows — no rounded corners, visible border, gaps
    tx = GAP
    ty = bar_h + GAP
    tw = TERM_W
    th = H - bar_h - GAP*2
    # border
    d.rectangle([tx-2, ty-2, tx+tw+1, ty+th+1], fill=rgb(wm_color))
    d.rectangle([tx, ty, tx+tw-1, ty+th-1], fill=rgb(BG))
    draw_fastfetch(d, fn, tx+6, ty+6, tw-12, th-12, os_name, "i3", pkgs)

    bx = GAP*2 + TERM_W
    by = bar_h + GAP
    bw = W - bx - GAP
    bh = H - bar_h - GAP*2
    d.rectangle([bx-2, by-2, bx+bw+1, by+bh+1], fill=rgb(wm_color))
    d.rectangle([bx, by, bx+bw-1, by+bh-1], fill=rgb(BG))
    pcx, pcy, pcw, pch = draw_brave(d, fn, bx, by, bw, bh)
    draw_github_page(d, fn, pcx, pcy, pcw, pch)

    img.save(path)
    print(f"  {path}")


def gen_niri(path, os_name, wm_color, pkgs):
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = fonts()

    bar_h = 28
    draw_waybar(d, fn, 0, bar_h, 1, wm_color,
                right="  CPU 4%  RAM 2.9G  12:34  2026-05-05 ")
    draw_wallpaper(d, 0, bar_h, W, H-bar_h)

    # Niri: columns with gaps, rounded
    tx = GAP
    ty = bar_h + GAP
    tw = TERM_W
    th = H - bar_h - GAP*2
    cx, cy, cw, ch = draw_window(d, fn, tx, ty, tw, th,
                                 "alacritty  —  zsh", wm_color, rounded=True)
    d.rectangle([cx, cy, cx+cw-1, cy+ch-1], fill=rgb(BG))
    draw_fastfetch(d, fn, cx+4, cy+4, cw-8, ch-8, os_name, "Niri", pkgs)

    bx = GAP*2 + TERM_W
    by = bar_h + GAP
    bw = W - bx - GAP
    bh = H - bar_h - GAP*2
    draw_window(d, fn, bx, by, bw, bh, "Brave", wm_color, rounded=True, titled=False)
    pcx, pcy, pcw, pch = draw_brave(d, fn, bx+1, by+1, bw-2, bh-2)
    draw_github_page(d, fn, pcx, pcy, pcw, pch)

    img.save(path)
    print(f"  {path}")


def gen_ratpoison(path, os_name, wm_color, pkgs):
    """Ratpoison: no gaps, no decorations, just a split + thin status bar."""
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = fonts()

    # ratpoison status bar at the top (very minimal)
    bar_h = 18
    d.rectangle([0, 0, W-1, bar_h-1], fill=rgb(BG3))
    d.text((6, 3), "ratpoison 1.4.9", font=fn["sm"], fill=rgb(DIM))
    d.text((W-80, 3), "12:34", font=fn["sm"], fill=rgb(FG2))

    # two windows split exactly 50/50, no gaps, no borders
    split = W // 2
    # left = terminal
    d.rectangle([0, bar_h, split-1, H-1], fill=rgb(BG))
    draw_fastfetch(d, fn, 8, bar_h+8, split-16, H-bar_h-16, os_name, "Ratpoison", pkgs)

    # thin divider
    d.line([split, bar_h, split, H-1], fill=rgb(BORDER))

    # right = icecat browser
    pcx, pcy, pcw, pch = draw_icecat(d, fn, split+1, bar_h, split-2, H-bar_h)
    draw_github_page(d, fn, pcx, pcy, pcw, pch)

    img.save(path)
    print(f"  {path}")


# ── Render all ─────────────────────────────────────────────────────────────
out = os.path.dirname(os.path.abspath(__file__))

print("Generating...")
gen_hyprland(os.path.join(out, "nixos-hyprland.png"),
             "NixOS", ACCENT, "1842 (nix)", draw_brave)

gen_ratpoison(os.path.join(out, "guix-ratpoison.png"),
              "GNU Guix", GREEN, "312 (guix)")

gen_niri(os.path.join(out, "arch-niri.png"),
         "Arch Linux", PURPLE, "1203 (pacman)")

gen_i3(os.path.join(out, "arch-i3.png"),
       "Arch Linux", YELLOW, "1187 (pacman)")

gen_hyprland(os.path.join(out, "arch-hyprland.png"),
             "Arch Linux", RED, "1241 (pacman)", draw_brave)

print("done.")
