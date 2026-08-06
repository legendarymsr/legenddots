# scripts

A collection of custom tools and configs. Tokyo Night themed throughout.

If you're using Chrome: a browser that reports everything you do back to
Google, exists solely to serve you ads, and treats you as the product —
you deserve better. If you're using Edge: a browser Microsoft force-installs
on your machine, nags you to set as default every 3 days, and is just Chrome
with extra telemetry and a Bing infestation. Both are spyware with a UI.

---

## browser

A terminal-based web browser built with [Textual](https://github.com/Textualize/textual).
Fetches pages over HTTP, converts HTML to Markdown, and renders it in the terminal.
Works on desktop and **Termux (Android)**.

**Install — Termux:**
```sh
pkg install python ca-certificates
pip install textual httpx html2text beautifulsoup4 pygments
```

**Install — desktop:**
```sh
pip install textual httpx html2text beautifulsoup4 pygments
```

`pygments` enables syntax highlighting in code blocks (`<pre><code class="language-X">`).
Language is auto-detected from the class attribute.

**Run:**
```sh
python browser
```

| Key | Action |
|-----|--------|
| Enter (in URL bar) | Load URL |
| `Ctrl+L` | Focus URL bar |
| `j` / `k` | Scroll down / up |
| `Ctrl+D` / `Ctrl+U` | Page down / up |
| `g` / `G` | Jump to top / bottom |
| `r` | Reload current page |
| `d` | Toggle diagnostics bar |
| `q` / `Ctrl+Q` | Quit |

- Renders headings, links, and code blocks with Tokyo Night styling
- After loading, the URL bar updates to the final redirected URL
- SSL errors show a specific Termux fix hint (`pkg install ca-certificates`)
- Has a special case to strikethrough anything with class `microsoft` on a page

---

## legend-gui

A custom Qt6 browser (`LegendChrome`) — **amnesic by design**, with tabs,
network-level ad blocking, YouTube ad-skipping, and qutebrowser-style keys.
Tokyo Night themed.

**Dependencies:** `PyQt6`, `PyQt6-WebEngine` (and `mpv` for `.m`)

```sh
python legend-gui [url]
```

**Amnesic:** off-the-record profile — **no history, no on-disk cookies, no
cache.** Session cookies live in RAM and vanish the instant you close it. This is
deliberate; there is no history/bookmark store to leak.

**Privacy / cookies:**
- **All third-party cookies blocked** at the store level (not just banner-hiding).
- `DNT: 1` and `Sec-GPC: 1` sent on every request.
- Cookie/consent banners auto-**rejected** (clicks "reject all" where it can) and
  hidden via CSS.

**Keys — qutebrowser-style, focus-aware** (typing in a page input never triggers
them):

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `f` | **hint links** — type the label to click | `.m` | send page to **mpv** |
| `Ctrl+T` / `Ctrl+W` | new / close tab | `Ctrl+L` | focus URL bar |
| `Alt+←` / `Alt+→` | back / forward | `Ctrl+R` / `F5` | reload |
| `Ctrl+Tab` | next tab | `Ctrl+±` / `Ctrl+0` | zoom / reset |
| `F11` | fullscreen | `Alt+Home` | home | `Ctrl+Q` | quit |

`f` overlays letter labels on every clickable element in view; type a label to
click it, `Esc` to cancel. `.m` hands the current URL to `mpv` (yt-dlp plays
YouTube etc. natively — much lighter than the embedded player on the Air).

**Ad blocker:** blocks known ad/tracking domains at the network level, matched by
host **suffix** (so `sub.doubleclick.net` is caught too) across ~45 built-ins —
Google Ads, DoubleClick, Criteo, Taboola, plus analytics/telemetry (Segment,
Amplitude, Mixpanel, Sentry, Clarity, …). Drop a hosts-format file at
`~/.config/legendchrome/blocklist.txt` (e.g. [StevenBlack's hosts](https://github.com/StevenBlack/hosts))
and it's merged in for thousands more. (That file is *read* only — no browsing
data is ever written.)

**YouTube:** auto-skips skippable ads, speeds unskippable ads to 16× (muted),
hides overlay/feed/masthead ads.

**Misc:** smart URL bar (non-URLs → Brave search), closable/movable tabs with
load progress, new-window/`target=_blank` links open as tabs, video fullscreen,
a modern Chrome user-agent (no QtWebEngine fallback), JetBrains Mono Nerd Font
site-wide, Chromium dark mode.

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
