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

**Dependencies:** `PyQt6`, `PyQt6-WebEngine` (and `mpv` for `.m`).

### Install on Gentoo

**Option A — Portage (system-wide).** Emerges the bindings + mpv. Portage package
names are **lowercase** (`dev-python/pyqt6-webengine`, not the pip distribution's
`PyQt6-WebEngine`). It pulls in **`dev-qt/qtwebengine:6`**, a Chromium-based package
— a long compile that wants a lot of RAM/disk, but it declares every X11 runtime lib
as a real dependency, so nothing is missing at launch:

```sh
sudo emerge -av dev-python/pyqt6-webengine media-video/mpv   # pyqt6 comes in as a dep
# sanity-check the bindings have the modules the browser uses (gui, widgets, network):
emerge -pv dev-python/pyqt6
```

Run it with the **system** python (not a venv):  `python ~/legenddots/scripts/legend-gui`.

**Option B — Python venv + pip (faster, skips the qtwebengine compile).** pip ships
prebuilt Qt wheels, so this avoids building `dev-qt/qtwebengine` from source:

```sh
python -m venv ~/.venvs/legend-gui
source ~/.venvs/legend-gui/bin/activate
pip install PyQt6 PyQt6-WebEngine
sudo emerge -av media-video/mpv          # mpv still comes from Portage
```

The pip Qt wheels bundle Qt/Chromium but still **dynamically link against system X11
libraries at runtime**. Portage doesn't pull these in for a pip install, so a fresh
box hits `ImportError: libXtst.so.6: cannot open shared object file` on first launch.
Install the Chromium runtime X11 deps once:

```sh
sudo emerge -1 \
  x11-libs/libXtst x11-libs/libXScrnSaver x11-libs/libXcomposite x11-libs/libXdamage \
  x11-libs/libXrandr x11-libs/libXcursor x11-libs/libXi x11-libs/libXext \
  x11-libs/libXrender x11-libs/libXfixes x11-libs/libxkbfile x11-libs/libxkbcommon \
  x11-libs/libxcb x11-libs/libxshmfence x11-libs/libdrm \
  dev-libs/nss dev-libs/nspr media-libs/alsa-lib media-libs/mesa net-print/cups
```

That's the full set QtWebEngine's Chromium links against; install them together so you
don't hit them one `.so` at a time (`libXtst` → `libxkbfile` → …). Option A avoids this
entirely — `dev-qt/qtwebengine:6` declares these as real dependencies. If a launch
*still* names a missing lib, list every one at once and map it to a package:

```sh
ldd ~/.venvs/legend-gui/lib/python*/site-packages/PyQt6/Qt6/lib/libQt6WebEngineCore.so.6 \
  | grep 'not found'
# then, for each libFoo.so:  e-file libFoo.so   (pfl:  sudo emerge app-portage/pfl)
```

### Run it

```sh
# Portage install — system python already has the bindings:
python ~/legenddots/scripts/legend-gui                 # opens the home page
python ~/legenddots/scripts/legend-gui example.com     # opens a URL

# venv install — activate first (or call the venv's python directly):
source ~/.venvs/legend-gui/bin/activate && python ~/legenddots/scripts/legend-gui
```

Make it a first-class command:

```sh
chmod +x ~/legenddots/scripts/legend-gui
ln -sf ~/legenddots/scripts/legend-gui ~/.local/bin/legend-gui   # then just: legend-gui
```

The shebang is `#!/usr/bin/env python3`, so on a Portage install `./legend-gui`
runs directly. On a venv install, run it with that venv active.

> **Wayland (niri) note:** if the window misbehaves or won't start under Wayland,
> force XWayland: `QT_QPA_PLATFORM=xcb legend-gui`. (QtWebEngine is happiest on
> XWayland.) The `QTWEBENGINE_CHROMIUM_FLAGS` the script sets are applied either way.

### Watching video (YouTube & friends)

**No proprietary codecs — enforced two ways.**

1. **Build level.** legend-gui ships *no* codecs of its own; it uses whatever
   QtWebEngine was built with. Built from source (Gentoo's `dev-qt/qtwebengine`,
   the libre default) it omits the patent-encumbered **H.264/AAC/HEVC** entirely —
   only free **VP8/VP9/AV1** + **Opus/Vorbis**. The pip `PyQt6-WebEngine` wheels
   are the exception: they bundle the official Qt binaries, which *do* include
   H.264/AAC and can't be stripped from a binary wheel.

2. **Usage level (default — this is what covers the wheels).** Regardless of the
   build, legend-gui **refuses the proprietary codecs at the JS layer**: it patches
   `canPlayType` / `MediaSource.isTypeSupported` / `mediaCapabilities` so
   H.264/AAC/HEVC/Dolby report as *unsupported*. So even on the pip wheel, sites
   feature-detect and serve free VP9/AV1+Opus, and the encumbered decoders never
   fire. Opt back in with `LEGENDCHROME_ALLOW_PROPRIETARY=1`.

So a pip install is fine for staying free — the codecs are present but unused.
If you want them *truly absent* from the build too, use the distro bindings
(`dev-python/PyQt6-WebEngine` against codec-free `dev-qt/qtwebengine`) or compile
against system Qt instead of the wheel:

```sh
pip install --no-binary PyQt6,PyQt6-WebEngine PyQt6 PyQt6-WebEngine
```

There are two ways to watch, and legend-gui does both.

**1. In the browser tab** — this needs QtWebEngine built with the **proprietary
codecs** (H.264 / AAC). YouTube serves royalty-free **VP9/AV1** to most clients, so
a lot of it plays with no codecs at all; but plenty of streams/sites are H.264-only.
On a **Portage** QtWebEngine you enable those by dropping `bindist` (the USE flag
that strips patent-encumbered code):

```sh
echo "dev-qt/qtwebengine -bindist" | sudo tee /etc/portage/package.use/qtwebengine
sudo emerge -av --newuse dev-qt/qtwebengine        # rebuilds with H.264/AAC
```

(The **pip** `PyQt6-WebEngine` wheels already ship with proprietary codecs, so the
venv route needs nothing extra here.)

**2. Hand it to mpv** — the `.m` key (whole page) and `F` (hint a single link) pipe
the URL to **mpv**, which uses **yt-dlp** to fetch the real stream. No embedded
Google player, no ads, no tracking, and it's far lighter than the in-page player:

```sh
sudo emerge -av media-video/mpv net-misc/yt-dlp
```

> If you want to watch proprietary garbage without selling your soul to Google,
> install mpv too.

**Recommendation: watch through mpv, always — don't feed the proprietary garbage.**
Even if you installed the pip wheel (codecs and all), you never have to *use* them:
route video to mpv with `.m` / `F` and the browser's bundled H.264/AAC — along with
Google's player, its ads, and its telemetry — are simply never loaded. yt-dlp hands
the raw stream to mpv; what mpv decodes it with is your own `ffmpeg`'s business, not
the browser's. So the codec question is really only about the *in-tab* player — skip
that player and it doesn't matter what the wheel shipped with.

**Amnesic:** off-the-record profile — **no history, no on-disk cookies, no
cache.** Session cookies live in RAM and vanish the instant you close it. This is
deliberate; there is no history/bookmark store to leak.

**Privacy / cookies:**
- **All third-party cookies blocked** at the store level (not just banner-hiding).
- `DNT: 1` and `Sec-GPC: 1` sent on every request.
- Cookie/consent banners auto-**rejected** (clicks "reject all" where it can) and
  hidden via CSS.

**Hardening (anti-fingerprint + anti-leak):**
- **WebRTC** locked to `default_public_interface_only` — no local/private-IP leak
  (the classic VPN de-anonymiser).
- **Canvas read-back blocked** (`ReadingFromCanvasEnabled=false`, Qt 6.6+) — kills
  the #1 fingerprinting vector; **UA Client-Hints off** and **Accept-Language
  frozen** to `en-US` so locale/UA can't be profiled.
- **Every capability prompt auto-denied**: geolocation, camera, mic, notifications.
- **Off:** JS clipboard reads, screen capture (`getDisplayMedia`), autoplay,
  insecure (mixed) content, and Chromium background phone-home (`<a ping>`,
  component/variations updates, Translate, OptimizationHints).

**Keys — qutebrowser-style, focus-aware** (typing in a page input never triggers
them):

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `f` | **hint links** — type label to click | `F` | **hint a link → mpv** |
| `.m` | send current page to **mpv** | `Esc` | cancel hinting |
| `Ctrl+T` / `Ctrl+W` | new / close tab | `Ctrl+L` | focus URL bar |
| `Alt+←` / `Alt+→` | back / forward | `Ctrl+R` / `F5` | reload |
| `Ctrl+Tab` | next tab | `Ctrl+±` / `Ctrl+0` | zoom / reset |
| `F11` | fullscreen | `Ctrl+Q` | quit (`Alt+Home` = home) |

`f` overlays letter labels on every clickable element in view; type a label to
click it. **`F` is the same but for mpv** — labels only appear on *links*, the
labels are **green** (so you know you're in mpv-hint mode), and picking one sends
that link's URL to `mpv` instead of navigating to it. `.m` does the same for the
current page. `Esc` cancels. yt-dlp lets mpv play YouTube and most video sites
natively — much lighter than the embedded player on the Air.

**Ad blocker — simple by default, one button to go heavy:**
- **Default:** a short core list (~14 domains — DoubleClick, Google Ads, Criteo,
  Taboola, …), matched by host **suffix** so `sub.doubleclick.net` is caught too.
- **The `🛡` button** (top-right of the URL bar) extends it: merges the extra
  analytics/telemetry set (Segment, Amplitude, Mixpanel, Sentry, Clarity, …) and
  then either a local `~/.config/legendchrome/blocklist.txt` or, if you don't
  have one, downloads [StevenBlack's hosts](https://github.com/StevenBlack/hosts)
  in the background — thousands of domains. The button turns green and shows the
  active count. (The download stays in memory; the local file is *read* only —
  no browsing data is ever written.)

**YouTube:** auto-skips skippable ads, speeds unskippable ads to 16× (muted),
hides overlay/feed/masthead ads.

**Misc:** smart URL bar (non-URLs → Brave search), closable/movable tabs with
load progress, new-window/`target=_blank` links open as tabs, video fullscreen,
a modern Chrome user-agent (no QtWebEngine fallback), JetBrains Mono Nerd Font
site-wide, Chromium dark mode.

### On "minimalism" — a note on suckless `surf`

[suckless](https://suckless.org) sells [`surf`](https://surf.suckless.org/) as a
*minimal* web browser. It's a ~2000-line C wrapper — around **webkit2gtk**, a
rendering engine of *millions* of lines, hard-built on **GTK**, the exact toolkit
that underpins GNOME. So the "minimal" browser cannot exist without the GNOME
stack it's supposedly above.

This is the same suckless whose [sucks page](https://suckless.org/sucks/) says:

> There are many broken X programs. Go bug the developers of these broken
> programs to fix them. Here are some of the main causes of this brokenness:
>
> The program assumes a specific window management model, e.g. assumes you are
> using a WIMP-window manager like those found in KDE or Gnome. This assumption
> breaks the ICCCM conventions.

Sneering at KDE/GNOME's window model while shipping a browser that needs GTK to
render a single pixel is a hell of a look. You can't dunk on GNOME and depend on
GNOME's toolkit in the same breath.

**And to be straight about `legend-gui`:** yes, the Python is minimal — a few
hundred lines. But it rides on **PyQt6 + QtWebEngine**, i.e. Chromium — tens of
millions of lines. My wrapper is small; the engine underneath is a leviathan.
That's true of *every* GUI browser that isn't its own from-scratch engine, surf
included. The difference is I'm not pretending the underlying stuff is minimal —
it isn't. Only the part I wrote is.

---

## edit — editor switcher (neovim ⇄ emacs)

Both **neovim** and **emacs** are first-class here, and they share one feel:
neovim natively, emacs via **evil-mode + a `SPC` leader** (`init.el`) — so the
same muscle memory works in either. Pick whichever suits the task; the system
follows your choice.

**How it's wired — system-wide, not just a shell alias:**
- `EDITOR`/`VISUAL`/`SUDO_EDITOR` are set in **`/etc/env.d/99legend-editor`** (the
  Gentoo way), pointing at **`/usr/local/bin/edit`**. So `git commit`, `doas -e`,
  `cron`, non-zsh shells, bare TTY logins, root — *everything* opens your chosen
  editor, not only your interactive zsh.
- **`edit`** and the **`editor`** switch command live in `/usr/local/bin` (on
  every user's PATH, including root). `gentoo/setup` installs them + runs
  `env-update`.
- The choice: per-user **`~/.config/legend/editor`** overrides the system default
  **`/etc/legend/editor`** (default `nvim`). Run `editor` as a normal user to set
  yours; as root to set the system default.
- Emacs runs as a **daemon** (`emacs --fg-daemon`, started by niri at login), so
  `emacsclient` opens **instantly**. Terminal-only (no GTK GUI): it lives in
  alacritty, just like neovim.
- **`man` opens in neovim** (`MANPAGER="nvim +Man!"`) with syntax highlight +
  vim navigation/search; emacs has `SPC h m` (`man`) / `SPC h i` (Info).
- **`vi` → neovim** system-wide (`eselect vi set nvim`), so even muscle-memory
  `vi` lands in nvim.
- **Both UIs are GUI-flavoured, in the terminal:**
  - *neovim* (`init.lua`): buffer tabs (bufferline), a centered command palette +
    notifications (noice + nvim-notify), indent guides, git gutter signs, a
    diagnostic scrollbar, smooth scrolling, full mouse.
  - *emacs* (`init.el`): Nerd-Font icons everywhere (tabs, completions, dired,
    modeline), GUI-style buffer tabs (centaur-tabs), IDE autocomplete popups
    (corfu + corfu-terminal), consult/embark command palette, git gutter
    (diff-hl margin), indent guides, rainbow brackets, helpful — all rendered in
    the TUI, no GUI/EXWM.

**Commands:**

| Command | Does |
|---------|------|
| `editor` | Show the current default (user + system) |
| `editor nvim` / `editor emacs` | Set the default (user pref; root → system) |
| `use-nvim` / `use-emacs` / `which-editor` | zsh shortcuts for the above |
| `v` | Always open **neovim** (regardless of default) |
| `e` | Always open **emacs** (terminal, via the daemon) |
| `edit <file>` | Open the current default editor (what `$EDITOR` runs) |

So `editor emacs` makes git/`doas`/`Mod+E` open emacs; `editor nvim` flips back.
`v`/`e` are always there for a one-off. `init.lua` (neovim) and `init.el` (emacs)
are both symlinked in by `gentoo/setup`; `Mod+E` opens the default in a terminal.

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
