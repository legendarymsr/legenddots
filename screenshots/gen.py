#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

# ── palette (Tokyo Night) ──────────────────────────────────────────────────
BG      = "#1a1b2e"
PANEL   = "#13141f"
CHROME  = "#0d0e1a"
BORDER  = "#3b4261"
FG      = "#c0caf5"
FG2     = "#a9b1d6"
DIM     = "#565f89"
ACCENT  = "#7aa2f7"
GREEN   = "#9ece6a"
RED     = "#f7768e"
YELLOW  = "#e0af68"
PURPLE  = "#bb9af7"
CYAN    = "#7dcfff"
ORANGE  = "#ff9e64"

MONO    = "/data/data/com.termux/files/home/.fonts/MononokiNerdFont-Bold.ttf"
MONO_R  = "/data/data/com.termux/files/home/.fonts/GoMonoNerdFont-Regular.ttf" \
          if os.path.exists("/data/data/com.termux/files/home/.fonts/GoMonoNerdFont-Regular.ttf") \
          else MONO
SANS    = "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans.ttf" \
          if os.path.exists("/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans.ttf") \
          else MONO

def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()

def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

W, H = 1280, 720
BAR   = 28
SPLIT = 556   # terminal / browser divider x

# ── ASCII logos ────────────────────────────────────────────────────────────
LOGOS = {
    "NixOS": {
        "color": ACCENT,
        "lines": [
            "  *  ",
            " /|\\ ",
            "* | *",
            " \\|/ ",
            "  *  ",
            "     ",
        ],
        "art": [
            "  \\\\  //  ",
            "  _\\\\//_  ",
            " (_    _) ",
            "  _//\\\\_ ",
            "  //  \\\\  ",
            "          ",
        ],
    },
    "GNU Guix": {
        "color": GREEN,
        "art": [
            " _________ ",
            "|  ______  |",
            "| | Guix | |",
            "| |______| |",
            "|___________|",
            "             ",
        ],
    },
    "Arch Linux": {
        "color": CYAN,
        "art": [
            "      /\\      ",
            "     /  \\     ",
            "    / /\\ \\    ",
            "   / /  \\ \\   ",
            "  /_/ arch\\_\\ ",
            "              ",
        ],
    },
}

COLOR_BLOCKS = [RED, GREEN, YELLOW, ACCENT, PURPLE, CYAN, FG2, DIM]

def draw_mockup(path, os_name, wm, bar_color, pkgs, kernel="6.6.30-zen1"):
    img  = Image.new("RGB", (W, H), hex2rgb(BG))
    d    = ImageDraw.Draw(img)

    f_mono_sm = font(MONO, 12)
    f_mono_md = font(MONO, 13)
    f_mono_lg = font(MONO, 14)
    f_sans_sm = font(SANS, 11)
    f_sans_md = font(SANS, 13)
    f_sans_lg = font(SANS, 15)
    f_sans_xl = font(SANS, 17)

    # ── top bar ──────────────────────────────────────────────────────────
    d.rectangle([0, 0, W-1, BAR-1], fill=hex2rgb(bar_color))
    # workspace dots
    for i, num in enumerate("1 2 3 4 5".split()):
        d.text((12 + i*22, 7), num, font=f_sans_sm, fill=hex2rgb(BG))
    # wm label centered
    label = f"{wm}  ·  {os_name}"
    bb = d.textbbox((0,0), label, font=f_sans_sm)
    lw = bb[2] - bb[0]
    d.text(((W - lw)//2, 7), label, font=f_sans_sm, fill=hex2rgb(BG))
    # clock
    d.text((W-52, 7), "12:34", font=f_sans_sm, fill=hex2rgb(BG))

    # ── left panel: terminal ──────────────────────────────────────────────
    d.rectangle([2, BAR, SPLIT-2, H-2], fill=hex2rgb(PANEL))
    # title bar
    d.rectangle([2, BAR, SPLIT-2, BAR+20], fill=hex2rgb(CHROME))
    for ci, col in enumerate([RED, YELLOW, GREEN]):
        cx = 14 + ci*16
        d.ellipse([cx-4, BAR+6, cx+4, BAR+14], fill=hex2rgb(col))
    d.text((60, BAR+5), "alacritty  —  zsh", font=f_sans_sm, fill=hex2rgb(DIM))

    # fastfetch logo
    logo = LOGOS.get(os_name, LOGOS["Arch Linux"])
    logo_color = hex2rgb(logo["color"])
    art = logo.get("art", logo.get("lines", []))
    lx, ly = 16, BAR + 28
    for line in art:
        d.text((lx, ly), line, font=f_mono_md, fill=logo_color)
        ly += 16

    # fastfetch info (right of logo)
    ix = 168
    iy = BAR + 28
    line_h = 16

    def info_line(key, val, key_col=CYAN, val_col=FG):
        nonlocal iy
        d.text((ix, iy),           key,  font=f_mono_md, fill=hex2rgb(key_col))
        d.text((ix + 90, iy),      val,  font=f_mono_md, fill=hex2rgb(val_col))
        iy += line_h

    user_label = f"user@legend"
    d.text((ix, iy), user_label, font=f_mono_md, fill=logo_color)
    iy += line_h
    d.text((ix, iy), "─" * 22, font=f_mono_sm, fill=hex2rgb(BORDER))
    iy += line_h

    info_line("OS",       os_name)
    info_line("Host",     "legend-box")
    info_line("Kernel",   kernel)
    info_line("WM",       wm)
    info_line("Pkgs",     pkgs)
    info_line("Shell",    "zsh 5.9")
    info_line("Term",     "Alacritty")
    info_line("Font",     "MononokiNF 12")
    info_line("Theme",    "Tokyo Night")
    iy += 6
    # color palette blocks
    for i, col in enumerate(COLOR_BLOCKS):
        bx = ix + i*22
        d.rectangle([bx, iy, bx+16, iy+10], fill=hex2rgb(col))

    # ── right panel: browser ──────────────────────────────────────────────
    bx0 = SPLIT + 2
    d.rectangle([bx0, BAR, W-2, H-2], fill=hex2rgb(PANEL))

    # browser chrome
    d.rectangle([bx0, BAR, W-2, BAR+58], fill=hex2rgb(CHROME))

    # tab
    tab_w = 230
    d.rounded_rectangle([bx0+6, BAR+4, bx0+6+tab_w, BAR+22], radius=4, fill=hex2rgb(PANEL))
    d.text((bx0+14, BAR+7), "legendarymsr/legenddots", font=f_sans_sm, fill=hex2rgb(FG2))

    # nav buttons (back/fwd/refresh)
    for bni, sym in enumerate(["←", "→", "↻"]):
        d.text((bx0+8 + bni*20, BAR+27), sym, font=f_sans_md, fill=hex2rgb(DIM))

    # url bar
    url_x0 = bx0 + 68
    url_x1 = W - 14
    d.rounded_rectangle([url_x0, BAR+25, url_x1, BAR+45], radius=4, fill=hex2rgb(BORDER))
    d.text((url_x0+8, BAR+29), "🔒 github.com/legendarymsr/legenddots", font=f_sans_sm, fill=hex2rgb(GREEN))

    # page body
    py = BAR + 66
    px = bx0 + 14

    # repo header
    d.text((px, py), "📦 legendarymsr / legenddots", font=f_sans_xl, fill=hex2rgb(FG))
    py += 24
    d.text((px, py), "Personal dotfiles for NixOS, Guix, and Arch Linux", font=f_sans_sm, fill=hex2rgb(FG2))
    py += 18
    # badges
    for badge_txt, badge_col in [("★ 0", YELLOW), ("MIT", GREEN), ("Nix · Guix · Arch", ACCENT)]:
        bb2 = d.textbbox((0,0), badge_txt, font=f_sans_sm)
        bw = bb2[2] - bb2[0] + 14
        d.rounded_rectangle([px, py, px+bw, py+14], radius=3, fill=hex2rgb(BORDER))
        d.text((px+7, py+1), badge_txt, font=f_sans_sm, fill=hex2rgb(badge_col))
        px += bw + 8
    px = bx0 + 14
    py += 22

    # divider
    d.line([bx0, py, W-2, py], fill=hex2rgb(BORDER))
    py += 12

    # readme content
    readme_lines = [
        (ACCENT,  "# legenddots"),
        (FG2,     ""),
        (FG,      "Personal dotfiles for NixOS, Guix, and Arch."),
        (FG2,     "Theme: Tokyo Night throughout."),
        (FG2,     ""),
        (YELLOW,  "## Screenshots"),
        (FG2,     ""),
        (CYAN,    f"### {os_name} — {wm}"),
        (FG2,     ""),
        (GREEN,   "## NixOS"),
        (FG,      "Fully declarative desktop. Hyprland, NixVim,"),
        (FG,      "home-manager, starship. One command to rebuild."),
        (FG2,     ""),
        (GREEN,   "## Guix"),
        (FG,      "Libre-only. Ratpoison, Emacs, Icecat, slock."),
        (FG,      "Hardened kernel, AppArmor, nftables."),
        (FG2,     ""),
        (GREEN,   "## Arch Rice"),
        (FG,      "Niri · i3 · Hyprland. Each self-contained."),
        (FG,      "install.sh symlinks and backs up existing configs."),
    ]
    for col, line in readme_lines:
        if py > H - 20:
            break
        d.text((px, py), line, font=f_mono_sm, fill=hex2rgb(col))
        py += 14

    img.save(path)
    print(f"  saved {path}")


RICES = [
    ("nixos-hyprland.png",  "NixOS",      "Hyprland",  ACCENT,  "1842 (nix)"),
    ("guix-ratpoison.png",  "GNU Guix",   "Ratpoison", GREEN,   "312 (guix)"),
    ("arch-niri.png",       "Arch Linux", "Niri",      PURPLE,  "1203 (pacman)"),
    ("arch-i3.png",         "Arch Linux", "i3",        YELLOW,  "1187 (pacman)"),
    ("arch-hyprland.png",   "Arch Linux", "Hyprland",  RED,     "1241 (pacman)"),
]

out = os.path.dirname(os.path.abspath(__file__))
for fname, os_name, wm, bar_col, pkgs in RICES:
    draw_mockup(os.path.join(out, fname), os_name, wm, bar_col, pkgs)

print("done.")
