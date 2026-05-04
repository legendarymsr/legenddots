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

def waybar_niri(d, fn, active=1, accent=PURPLE,
                right_txt="  Niri   CPU 4%   RAM 2.9G   12:34 "):
    """Niri waybar — flush with screen edges, workspace pills."""
    BAR_H = 28
    d.rectangle([0, 0, W, BAR_H], fill=rgb(BG2))
    d.line([0, BAR_H-1, W, BAR_H-1], fill=rgb(BORDER))
    x = 8
    for i in range(1, 6):
        s = str(i)
        active_ws = (i == active)
        pill_w = 24
        fill = accent if active_ws else BG3
        d.rounded_rectangle([x, 4, x+pill_w, BAR_H-4], radius=4, fill=rgb(fill))
        lw_ = tw(d, s, fn["bar"])
        d.text((x+(pill_w-lw_)//2, 7), s, font=fn["bar"],
               fill=rgb(BG if active_ws else DIM))
        x += pill_w + 3
    # Niri-specific: column position indicator
    col_ind = "col 2/4"
    d.text((x+10, 7), col_ind, font=fn["bar"], fill=rgb(DIM))
    # center title
    title = "alacritty  —  zsh"
    lw_ = tw(d, title, fn["bar"])
    d.text(((W-lw_)//2, 7), title, font=fn["bar"], fill=rgb(FG2))
    # right
    rw_ = tw(d, right_txt, fn["bar"])
    d.text((W-rw_-4, 7), right_txt, font=fn["bar"], fill=rgb(FG2))
    return BAR_H

def waybar_floating(d, fn, img, active=1, accent=ACCENT,
                    right_txt="  CPU 6%   RAM 3.4G   12:34 "):
    """Hyprland floating waybar — pill inset from screen edges, wallpaper visible above/beside."""
    M   = 8   # margin from screen edge
    BAR_H = 30
    # the bar is a rounded pill floating over wallpaper
    d.rounded_rectangle([M, M, W-M, M+BAR_H], radius=14,
                         fill=rgb(BG2), outline=rgb(BORDER), width=1)
    # workspace pills
    x = M + 10
    for i in range(1, 6):
        s = str(i)
        active_ws = (i == active)
        pill_w = 24
        fill = accent if active_ws else BG4
        d.rounded_rectangle([x, M+5, x+pill_w, M+BAR_H-5], radius=5, fill=rgb(fill))
        lw_ = tw(d, s, fn["bar"])
        d.text((x+(pill_w-lw_)//2, M+8), s, font=fn["bar"],
               fill=rgb(BG if active_ws else DIM))
        x += pill_w + 3
    # center
    title = "nvim  —  flake.nix"
    lw_ = tw(d, title, fn["bar"])
    d.text(((W-lw_)//2, M+8), title, font=fn["bar"], fill=rgb(FG2))
    # right modules with colored pills
    modules = [
        ("  CPU 6%  ", BG4),
        ("  RAM 3.4G  ", BG4),
        ("  12:34  ", accent),
    ]
    rx = W - M - 6
    for txt, bg in reversed(modules):
        mw = tw(d, txt, fn["bar"]) + 6
        rx -= mw + 2
        d.rounded_rectangle([rx, M+5, rx+mw, M+BAR_H-5], radius=4, fill=rgb(bg))
        d.text((rx+3, M+8), txt, font=fn["bar"],
               fill=rgb(BG if bg == accent else FG2))
    return M + BAR_H + M   # total space consumed from top

def polybar_bottom(d, fn, active=1, accent=YELLOW):
    """i3 polybar at the bottom — wide powerline blocks, date on right."""
    BAR_H = 26
    by = H - BAR_H
    d.rectangle([0, by, W, H], fill=rgb(BG))
    # workspaces
    x = 0
    for i in range(1, 10):
        s = f" {i} "
        lw_ = tw(d, s, fn["bar_b"])
        active_ws = (i == active)
        fill = accent if active_ws else (BG3 if i <= 5 else BG)
        d.rectangle([x, by, x+lw_, H], fill=rgb(fill))
        d.text((x, by+5), s, font=fn["bar_b"],
               fill=rgb(BG if active_ws else (FG2 if i <= 5 else DIM)))
        x += lw_
    # powerline sep
    d.text((x, by+2), "▌", font=fnt(SANS_B, 20), fill=rgb(BG3))
    x += 14
    d.text((x+4, by+5), "alacritty  —  git log", font=fn["bar"], fill=rgb(FG2))
    # right: date time in colored blocks
    right_mods = [
        ("  2026-05-05 ", BG3),
        (f"  12:34 ", accent),
        ("  VOL 65% ", BG3),
        ("  CPU 8%  RAM 4G ", BG4),
    ]
    rx = W
    for txt, bg in reversed(right_mods):
        mw = tw(d, txt, fn["bar"])
        rx -= mw
        d.rectangle([rx, by, rx+mw, H], fill=rgb(bg))
        d.text((rx, by+5), txt, font=fn["bar"],
               fill=rgb(BG if bg == accent else FG2))
    return by   # windows fill y=0 to y=by

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

# ── Actual init.lua (Neovim config) ───────────────────────────────────────
LUA_CODE = [
    ("-- Legend@Yuki // RED TEAM COMMAND & CONTROL v25.0 [STABILIZED]", DIM),
    ("",                                                                  FG),
    ("-- 1. BOOTSTRAP LAZY.NVIM",                                        DIM),
    ('local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"',    CYAN),
    ("vim.opt.rtp:prepend(lazypath)",                                    CYAN),
    ("",                                                                  FG),
    ("-- 2. SYSTEM HARDENING (The Fundamentals)",                        DIM),
    ('vim.g.mapleader        = " "',                                     CYAN),
    ("vim.opt.number         = true",                                    CYAN),
    ("vim.opt.relativenumber = true",                                    CYAN),
    ("vim.opt.termguicolors  = true",                                    CYAN),
    ("vim.opt.shiftwidth     = 2",                                       CYAN),
    ("vim.opt.tabstop        = 2",                                       CYAN),
    ('vim.opt.clipboard      = "unnamedplus"',                           CYAN),
    ("vim.opt.undofile       = true",                                    CYAN),
    ("vim.opt.cursorline     = true",                                    CYAN),
    ("",                                                                  FG),
    ("-- 3. THE PLUGINS",                                               DIM),
    ('require("lazy").setup({',                                          PURPLE),
    ("  -- THEME: TokyoNight",                                          DIM),
    ("  {",                                                              FG),
    ('    "folke/tokyonight.nvim",',                                     GREEN),
    ("    lazy = false, priority = 1000,",                               FG),
    ("    config = function()",                                          PURPLE),
    ('      require("tokyonight").setup({',                              PURPLE),
    ('        style = "night", transparent = false,',                    GREEN),
    ("      })",                                                         FG),
    ("      vim.cmd[[colorscheme tokyonight-night]]",                    CYAN),
    ("    end,",                                                         FG),
    ("  },",                                                             FG),
    ('  { "folke/which-key.nvim",        event = "VeryLazy" },',        GREEN),
    ('  { "kdheepak/lazygit.nvim",       cmd   = { "LazyGit" } },',     GREEN),
    ('  { "nvim-telescope/telescope.nvim", tag = "0.1.8" },',           GREEN),
    ('  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },',   GREEN),
    ('  { "nvim-tree/nvim-tree.lua" },',                                 GREEN),
    ('  { "nvim-lualine/lualine.nvim" },',                              GREEN),
    ("})",                                                               FG),
    ("",                                                                  FG),
    ("-- 6. KEYMAPS (Pure Efficiency)",                                 DIM),
    ('vim.keymap.set("n","<leader>ff","<cmd>Telescope find_files<cr>")', CYAN),
    ('vim.keymap.set("n","<leader>gg","<cmd>LazyGit<CR>")',             CYAN),
    ('vim.keymap.set("n","<leader>e", "<cmd>NvimTreeToggle<CR>")',      CYAN),
    ('vim.keymap.set("t","<Esc>",    [[<C-\\><C-n>]])',                 CYAN),
]

def draw_nvim_pane(d, fn, x, y, w, h, filename="init.lua", code=None, accent=ACCENT):
    """Neovim mockup with line numbers, syntax-coloured code, lualine statusbar."""
    if code is None:
        code = LUA_CODE
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

    # ── tmux/ratpoison split + editor pane ────────────────────────────────
    remaining = (cy + ch) - iy
    if remaining > 60:
        TMUX_H = 16
        editor_label = getattr(draw_terminal, "_editor", "nvim")
        d.rectangle([cx, iy, cx+cw, iy+TMUX_H], fill=rgb(BG3))
        d.rectangle([cx, iy, cx+60, iy+TMUX_H], fill=rgb(GREEN))
        d.text((cx+4, iy+2), "1:zsh", font=fn["tiny"], fill=rgb(BG))
        d.rectangle([cx+62, iy, cx+120, iy+TMUX_H], fill=rgb(BG4))
        d.text((cx+66, iy+2), f"2:{editor_label}", font=fn["tiny"], fill=rgb(FG2))
        d.text((cx+cw-80, iy+2), "legend-box  12:34", font=fn["tiny"], fill=rgb(DIM))
        iy += TMUX_H

        if editor_label == "emacs":
            draw_emacs_editor(d, fn, cx, iy, cw, cy+ch-iy, filename="init.el")
        else:
            draw_nvim_pane(d, fn, cx, iy, cw, cy+ch-iy, filename="init.lua")

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
# Emacs frame helper — shared chrome (menu bar, modeline, minibuffer)
# ══════════════════════════════════════════════════════════════════════════
MENU_H     = 20
MODELINE_H = 18
MINIBUF_H  = 16

def _emacs_chrome(d, fn, x, y, w, h, modeline_txt):
    """Draw Emacs menu bar + modeline + minibuffer. Returns content rect."""
    # menu bar
    d.rectangle([x, y, x+w, y+MENU_H], fill=rgb(BG3))
    d.line([x, y+MENU_H-1, x+w, y+MENU_H-1], fill=rgb(BORDER))
    mx = x + 6
    for item in ["File", "Edit", "Options", "Buffers", "Tools", "Help"]:
        d.text((mx, y+4), item, font=fn["bar"], fill=rgb(FG2))
        mx += tw(d, item, fn["bar"]) + 14

    content_y = y + MENU_H
    content_h = h - MENU_H - MODELINE_H - MINIBUF_H

    # modeline — dark bar, full width
    ml_y = content_y + content_h
    d.rectangle([x, ml_y, x+w, ml_y+MODELINE_H], fill=rgb(BG4))
    d.rectangle([x, ml_y, x+w, ml_y+1], fill=rgb(DIM))
    d.text((x+4, ml_y+3), modeline_txt, font=fn["mono_r"], fill=rgb(FG2))

    # minibuffer
    mb_y = ml_y + MODELINE_H
    d.rectangle([x, mb_y, x+w, mb_y+MINIBUF_H], fill=rgb(BG))
    d.rectangle([x+4, mb_y+3, x+12, mb_y+MINIBUF_H-3], fill=rgb(FG))

    return x, content_y, w, content_h


# ══════════════════════════════════════════════════════════════════════════
# Emacs EWW — plain text buffer, no browser chrome
# EWW renders pages as flowing monospace text. No tabs, no address bar.
# The URL is the first line of the buffer itself.
# ══════════════════════════════════════════════════════════════════════════
def draw_emacs_eww(d, fn, x, y, w, h):
    d.rectangle([x, y, x+w, y+h], fill=rgb(BG))

    modeline = ("-U:---  *eww*   All L1     (EWW)"
                + "-" * 40)
    bx, by, bw, bh = _emacs_chrome(d, fn, x, y, w, h, modeline)

    lh = 13
    px = bx + 8
    py = by + 4

    def line(text, col=FG2, ul=False):
        nonlocal py
        if py + lh > by + bh - 2:
            return
        d.text((px, py), text, font=fn["mono_r"], fill=rgb(col))
        if ul:
            lw = tw(d, text, fn["mono_r"])
            d.line([px, py+lh-2, px+lw, py+lh-2], fill=rgb(col))
        py += lh

    def gap(n=1):
        nonlocal py
        py += lh * n // 2

    # ── EWW buffer contents ───────────────────────────────────────────────
    # First line of buffer = the URL (no separate address bar in real EWW)
    line("github.com/legendarymsr/legenddots", CYAN, ul=True)
    gap()

    # EWW navigation buttons rendered as inline text in the buffer
    nav = "[back]  [forward]  [reload]  [history]"
    d.text((px, py), nav, font=fn["mono_r"], fill=rgb(DIM))
    py += lh
    gap()

    # Page content — EWW renders GitHub as plain text
    line("legendarymsr / legenddots", FG, ul=False)
    line("=" * 34, BORDER)
    gap()

    line("Personal dotfiles for NixOS, Guix, and Arch Linux.")
    line("Theme: Tokyo Night throughout.")
    gap()

    # GitHub tabs rendered as plain links
    for tab in ["[< > Code]", "[Issues]", "[Pull requests]", "[Actions]"]:
        d.text((px, py), tab + "  ", font=fn["mono_r"], fill=rgb(ACCENT))
        tw_ = tw(d, tab + "  ", fn["mono_r"])
        d.line([px, py+lh-2, px+tw_-4, py+lh-2], fill=rgb(ACCENT))
        px += tw_
    py += lh
    px = bx + 8
    gap()

    # File listing — EWW renders tables as plain text rows
    line("flake.nix              NixOS flake               3 days ago", FG2)
    line("configuration.nix      NixOS stub                3 days ago", FG2)
    line("home.nix               Home-manager entry        3 days ago", FG2)
    line("home/                  packages, nixvim          3 days ago", FG2)
    line("config.scm             Guix system config        1 day ago",  FG2)
    line("home-configuration.scm Guix home (ratpoison)     1 day ago",  FG2)
    line("alacritty.toml         Tokyo Night, 95% opacity  5 days ago", FG2)
    line("hyprland/              Hyprland rice             2 days ago", FG2)
    line("i3/                    i3 rice                   2 days ago", FG2)
    line("niri/                  Niri rice                 2 days ago", FG2)
    line("screenshots/           Mockup screenshots        just now",   FG2)
    line("README.md              Expand explanations       just now",   FG2)
    gap()

    line("legenddots", ACCENT)
    line("──────────", BORDER)
    line("Personal dotfiles for NixOS, Guix, and Arch Linux.")
    line("Theme: Tokyo Night throughout.")
    gap()
    line("NixOS", GREEN)
    line("  Fully declarative desktop. Hyprland, NixVim, home-manager.")
    gap()
    line("Guix", GREEN)
    line("  Libre-only. Ratpoison, Emacs, slock. Hardened kernel,")
    line("  AppArmor, nftables, fail2ban.")
    gap()
    line("Arch Rice", GREEN)
    line("  Niri · i3 · Hyprland. install.sh per rice.")


# ══════════════════════════════════════════════════════════════════════════
# Emacs editor buffer — shows init.el with elisp syntax colouring
# ══════════════════════════════════════════════════════════════════════════
ELISP_CODE = [
    (";; LegendOS Bunker: Red Team Edition v5.0 — GPL-3.0",  DIM),
    (";; Freedom is not granted — it is taken and defended.", DIM),
    ("",                                                      FG),
    (";; --- 0. PRELIMINARIES ---",                           DIM),
    ("(setq inhibit-startup-message t)",                      FG),
    ("(if (display-graphic-p)",                               PURPLE),
    ("    (progn",                                            PURPLE),
    ("      (menu-bar-mode -1)",                              FG),
    ("      (tool-bar-mode -1)",                              FG),
    ("      (scroll-bar-mode -1)))",                          FG),
    ("(setq display-line-numbers-type 'relative)",            FG),
    ("(add-hook 'prog-mode-hook #'display-line-numbers-mode)", CYAN),
    ("",                                                      FG),
    (";; --- 1. PACKAGE MANAGEMENT ---",                      DIM),
    ("(require 'package)",                                    PURPLE),
    ("(setq package-archives",                                PURPLE),
    (' \'(("melpa"  . "https://melpa.org/packages/")',         GREEN),
    ('   ("gnu"    . "https://elpa.gnu.org/packages/")))',    GREEN),
    ("(package-initialize)",                                   PURPLE),
    ("(setq use-package-always-ensure t)",                    FG),
    ("",                                                      FG),
    (";; --- 2. EVIL MODE ---",                               DIM),
    ("(use-package evil",                                     PURPLE),
    ("  :init",                                               CYAN),
    ("  (setq evil-want-integration t)",                      FG),
    ("  (setq evil-want-keybinding nil)",                     FG),
    ("  :config (evil-mode 1))",                              FG),
    ("(use-package evil-collection",                          PURPLE),
    ("  :after evil",                                         CYAN),
    ("  :config (evil-collection-init))",                     FG),
    ("",                                                      FG),
    (";; --- 3. SPC LEADER KEY ---",                          DIM),
    ("(use-package general",                                  PURPLE),
    ("  :config",                                             CYAN),
    ("  (general-evil-setup t)",                              FG),
    ("  (general-create-definer leader",                      FG),
    ('    :states \'(normal visual insert emacs)',             GREEN),
    ('    :prefix "SPC")',                                    GREEN),
    ("  (leader",                                             FG),
    ('    "ff" \'(find-file :which-key "Find file")',         YELLOW),
    ('    "bb" \'(consult-buffer :which-key "Buffers")',      YELLOW),
    ('    "gg" \'(magit-status :which-key "Magit")',          YELLOW),
    ('    "tt" \'(eshell :which-key "Open terminal")))',       YELLOW),
    ("",                                                      FG),
    (";; --- 6. THEME + MODELINE ---",                        DIM),
    ("(use-package doom-themes",                              PURPLE),
    ("  :config (load-theme 'doom-one t))",                   GREEN),
    ("(use-package doom-modeline",                            PURPLE),
    ("  :init (doom-modeline-mode 1))",                       FG),
    ("(use-package which-key",                                PURPLE),
    ("  :init (which-key-mode)",                              FG),
    ("  :config (setq which-key-idle-delay 0.3))",            FG),
    ("",                                                      FG),
    (";; --- 5. MAGIT ---",                                   DIM),
    ("(use-package magit",                                    PURPLE),
    ("  :bind (\"C-x g\" . magit-status))",                   GREEN),
]

def draw_emacs_editor(d, fn, x, y, w, h, filename="init.el"):
    d.rectangle([x, y, x+w, y+h], fill=rgb(BG))
    modeline = (f"-U:---  {filename}   All L1     (Emacs-Lisp)"
                + "-" * 30)
    bx, by, bw, bh = _emacs_chrome(d, fn, x, y, w, h, modeline)

    LN_W = 30
    lh   = 13
    cy2  = by + 4

    for i, (code_line, col) in enumerate(ELISP_CODE):
        if cy2 + lh > by + bh - 2:
            break
        ln = str(i + 1).rjust(3)
        d.text((bx+2,    cy2), ln,        font=fn["mono_r"], fill=rgb(DIM))
        d.text((bx+LN_W, cy2), code_line, font=fn["mono_r"], fill=rgb(col))
        cy2 += lh

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

    bar_h = waybar_floating(d, fn, img, accent=accent)
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


GIT_LOG = [
    ("0f33cb5", "Guix: proper EWW (plain text buffer, no chrome)"),
    ("7bb4669", "Fill empty space: nvim pane + full README"),
    ("2cc5275", "Mockups: visually distinct per WM"),
    ("8591126", "Redesign mockups with realistic WM layouts"),
    ("36a030e", "Add Tokyo Night mockup screenshots"),
    ("ece5905", "Add screenshots section to README"),
    ("569a8da", "Expand README with full rice explanations"),
    ("064e725", "Fix ratpoison config, remove non-libre pkgs"),
    ("2383261", "Harden Guix: noexec, SSH crypto, fail2ban"),
    ("1fe5ba1", "Note brave is stable on NixOS"),
    ("e81f009", "Mod+q exit, Mod+Shift+q close, Tab cycle"),
]

def draw_gitlog(d, fn, x, y, w, h):
    """Simple git log --oneline output filling a terminal pane."""
    d.rectangle([x, y, x+w, y+h], fill=rgb(BG))
    px, py = x+6, y+6
    lh = 14

    d.text((px, py), "user@legend ~/legenddots git:(master) ❯ git log --oneline",
           font=fn["mono_r"], fill=rgb(FG2))
    py += lh + 2

    for sha, msg in GIT_LOG:
        if py + lh > y + h - 4:
            break
        d.text((px,      py), sha, font=fn["mono_b"], fill=rgb(YELLOW))
        d.text((px + 58, py), msg, font=fn["mono_r"], fill=rgb(FG))
        py += lh

    py += 4
    if py + lh <= y + h:
        d.text((px, py), "user@legend ~/legenddots git:(master) ❯ ",
               font=fn["mono_r"], fill=rgb(FG2))
        cursor_x = px + tw(d, "user@legend ~/legenddots git:(master) ❯ ", fn["mono_r"])
        d.rectangle([cursor_x, py+2, cursor_x+8, py+lh-2], fill=rgb(FG))


def gen_i3(outpath, os_name, accent, pkgs):
    """i3: polybar + LEFT SIDE SPLIT (terminal top / git log bottom) + browser right."""
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = make_fonts()

    bar_h = H   # polybar_bottom returns the y where windows end (bar is at bottom)
    bot_y = polybar_bottom(d, fn, accent=accent)
    wallpaper(img, 0, 0, W, bot_y)

    SG = 4   # i3-gaps small gap
    LEFT_W = 470
    RIGHT_X = SG*2 + LEFT_W
    RIGHT_W = W - RIGHT_X - SG
    FULL_H  = bot_y - SG*2

    # Left side: two stacked windows (i3 horizontal split)
    TOP_H = int(FULL_H * 0.55)
    BOT_H = FULL_H - TOP_H - SG

    # Top-left: terminal with fastfetch
    cx, cy, cw, ch = i3_window(d, fn, SG, SG, LEFT_W, TOP_H,
                                "alacritty  —  zsh", accent, active=True)
    draw_terminal(d, fn, cx+2, cy+2, cw-4, ch-4, os_name, "i3", pkgs)

    # Bottom-left: git log
    bly = SG + TOP_H + SG
    cx2, cy2, cw2, ch2 = i3_window(d, fn, SG, bly, LEFT_W, BOT_H,
                                    "alacritty  —  git log", accent, active=False)
    draw_gitlog(d, fn, cx2, cy2+2, cw2, ch2-2)

    # Right: browser (full height)
    cx3, cy3, cw3, ch3 = i3_window(d, fn, RIGHT_X, SG, RIGHT_W, FULL_H,
                                    "Brave  —  github.com/legendarymsr/legenddots",
                                    accent, active=False)
    pcx, pcy, pcw, pch = draw_brave(d, fn, cx3, cy3, cw3, ch3)
    draw_github(d, fn, pcx, pcy, pcw, pch)

    img.save(outpath)
    print(f"  {outpath}")


def gen_niri(outpath, os_name, accent, pkgs):
    """Niri: THREE scrollable columns — terminal | browser | partial nvim clipped at edge."""
    img = Image.new("RGB", (W, H), rgb(BG))
    d   = ImageDraw.Draw(img)
    fn  = make_fonts()

    bar_h = waybar_niri(d, fn, accent=accent,
                       right_txt="  Niri   CPU 4%   RAM 2.9G   12:34 ")
    wallpaper(img, 0, bar_h, W, H-bar_h)

    ty = bar_h + GAP
    th = H - bar_h - GAP*2

    COL1 = 310   # terminal
    COL2 = 530   # browser
    # COL3 starts at GAP+COL1+GAP+COL2+GAP = 8+310+8+530+8 = 864
    # visible width = W-8-864 = 408 of a 420-wide window (clipped naturally)
    COL3_START = GAP + COL1 + GAP + COL2 + GAP
    COL3_FULL  = 420
    COL3_VIS   = W - COL3_START   # no right gap — clips at screen edge

    # column 1 — terminal
    cx, cy, cw, ch = hyprland_window(d, fn, GAP, ty, COL1, th,
                                      "alacritty  —  zsh", accent)
    draw_terminal(d, fn, cx+2, cy+2, cw-4, ch-4, os_name, "Niri", pkgs)

    # column 2 — browser
    bx = GAP + COL1 + GAP
    hyprland_window(d, fn, bx, ty, COL2, th, "Brave", accent)
    pcx, pcy, pcw, pch = draw_brave(d, fn, bx+2, ty+2, COL2-4, th-4)
    draw_github(d, fn, pcx, pcy, pcw, pch)

    # column 3 — neovim, partially clipped (shows scroll nature)
    # draw a full window but clip it at the right edge by only drawing within [COL3_START, W]
    nx3 = COL3_START
    # window border + bg
    d.rounded_rectangle([nx3, ty, nx3+COL3_FULL, ty+th],
                         radius=10, outline=rgb(DIM), width=2, fill=rgb(BG2))
    # title bar
    d.rounded_rectangle([nx3+2, ty+2, nx3+COL3_FULL-2, ty+26],
                         radius=9, fill=rgb(BG3))
    d.rectangle([nx3+2, ty+15, nx3+COL3_FULL-2, ty+26], fill=rgb(BG3))
    d.text((nx3+10, ty+7), "nvim  —  flake.nix", font=fn["title"], fill=rgb(DIM))
    # content area
    d.rectangle([nx3+2, ty+27, nx3+COL3_FULL-2, ty+th-2], fill=rgb(BG))
    draw_nvim_pane(d, fn, nx3+4, ty+28, COL3_FULL-8, th-32,
                   filename="flake.nix", accent=DIM)

    # "more to the right" scroll shadow at right edge
    for i in range(20):
        alpha = int(200 * i / 20)
        shade = tuple(max(0, c - alpha//6) for c in rgb(BG))
        d.line([W-20+i, bar_h, W-20+i, H], fill=shade)

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
    draw_terminal._editor = "emacs"
    draw_terminal(d, fn, lx, ly, lw, lh, os_name, "Ratpoison", pkgs)
    draw_terminal._editor = "nvim"

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
