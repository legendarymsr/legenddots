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

A custom Qt6 browser (`LegendChrome`) with tabs, network-level ad blocking,
YouTube ad-skipping, and persistent logins. Tokyo Night themed.

**Dependencies:** `PyQt6`, `PyQt6-WebEngine`

```sh
python legend-gui [url]
```

**Tabs & navigation:** multiple closable/movable tabs, smart URL bar (types that
aren't URLs become a Brave search), per-tab load progress, and keyboard shortcuts:

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `Ctrl+T` | new tab | `Ctrl+W` | close tab |
| `Ctrl+L` | focus URL bar | `Ctrl+R` / `F5` | reload |
| `Alt+←` / `Alt+→` | back / forward | `Ctrl+Tab` | next tab |
| `Ctrl+±` / `Ctrl+0` | zoom / reset | `F11` | fullscreen |
| `Alt+Home` | home | `Ctrl+Q` | quit |

**Ad blocker:** blocks known ad/tracking domains at the network level, matched by
host **suffix** (so `sub.doubleclick.net` is caught too), across ~45 built-in
domains — Google Ads, DoubleClick, Criteo, Taboola, plus analytics/telemetry
(Segment, Amplitude, Mixpanel, Sentry, Clarity, …). Drop a hosts-format file at
`~/.config/legendchrome/blocklist.txt` (e.g. [StevenBlack's hosts](https://github.com/StevenBlack/hosts))
and it's merged in for thousands more.

**YouTube:** auto-skips skippable ads, speeds unskippable ads to 16× (muted),
hides overlay/feed/masthead ads and cookie banners via injected CSS/JS.

**Persistence:** a named profile at `~/.config/legendchrome/` keeps cookies and
logins across restarts (with cache + downloads to `~/Downloads`). A modern
Chrome user-agent is set so sites don't serve the QtWebEngine fallback.

**Styling:** JetBrains Mono Nerd Font forced site-wide, Chromium dark mode,
Tokyo Night URL bar and tab bar. New-window/`target=_blank` links open as tabs;
video fullscreen works.

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
