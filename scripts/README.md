# scripts

A collection of custom tools and configs. Tokyo Night themed throughout.

---

## browser

A terminal-based web browser built with [Textual](https://github.com/Textualize/textual).
Fetches pages over HTTP, converts HTML to Markdown, and renders it in the terminal.

**Dependencies:** `textual`, `httpx`, `html2text`, `beautifulsoup4`

```sh
python browser
```

- Address bar at the top, type a URL and press Enter
- `q` to quit
- Renders headings, links, and code blocks with Tokyo Night styling
- Has a special case to strikethrough anything with class `microsoft` on a page

---

## legend-gui

A custom Qt6 browser (`LegendChrome`) with built-in ad blocking and YouTube ad skipping.

**Dependencies:** `PyQt6`, `PyQt6-WebEngine`

```sh
python legend-gui
```

**Ad blocker:** Blocks requests to known ad/tracking domains at the network level
(Google Ads, DoubleClick, Facebook Pixel, Criteo, Hotjar, OneTrust, Taboola, etc.)

**YouTube:** Auto-skips skippable ads, speeds up unskippable ads to 16x, hides
overlay ads and cookie banners via injected CSS/JS.

**Styling:** JetBrains Mono Nerd Font forced site-wide, dark mode enabled via
Chromium flags, Tokyo Night URL bar.

---

## qute-config.py

Tokyo Night themed [qutebrowser](https://qutebrowser.org) config with Neovim-style keybinds.

### Search engines

| Key | Engine |
|-----|--------|
| DEFAULT / `b` | Brave Search |
| `d` | DuckDuckGo |
| `w` | Wikipedia |
| `r` | Reddit (via Brave Search) |
| `y` | YouTube |
| `a` | Arch Wiki |
| `g` | Gentoo AMD64 Handbook |

Use `Ctrl-o` + key to open a search in a new tab (e.g. `Ctrl-o a` for Arch Wiki).

### Keybinds

| Key | Action |
|-----|--------|
| `o` | Open URL in current tab |
| `t` | Open URL in new tab |
| `H` / `L` | Back / Forward |
| `J` / `K` | Next / Previous tab |
| `x` / `X` | Close tab / Undo close |
| `d` / `u` | Scroll half page down / up |
| `f` / `F` | Hint links (current / background tab) |
| `yy` / `yt` / `yd` | Yank URL / title / domain |
| `;` | Command mode |
| `Ctrl-e` | Edit text box in Neovim |
| `,m` | Open current URL in mpv |
| `,M` | Hint a link to open in mpv |

Text boxes open in Neovim via Alacritty with `Ctrl-e` in insert mode.
