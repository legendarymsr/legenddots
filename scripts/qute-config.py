# LEGEND QUTEBROWSER CONFIG v1.0
import os

# --- 1. CORE & PERFORMANCE ---
config.load_autoconfig(False)
c.content.javascript.enabled = True 
c.scrolling.smooth = True
c.content.blocking.method = 'both' # Adblock on
c.fonts.default_family = 'JetBrainsMono Nerd Font'
c.fonts.default_size = '11pt'

# --- 2. SEARCH ENGINES (Ctrl+o -> Key) ---
c.url.searchengines = {
    'DEFAULT': 'https://search.brave.com/search?q={}', 
    'b': 'https://search.brave.com/search?q={}',
    'd': 'https://duckduckgo.com/?q={}',
    'w': 'https://en.wikipedia.org/w/index.php?search={}',
    'r': 'https://search.brave.com/search?q=site:reddit.com+{}', # Smart Reddit
    'g': 'https://www.google.com/search?q={}',
    'y': 'https://www.youtube.com/results?search_query={}',
    'a': 'https://wiki.archlinux.org/?search={}' 
}

# --- 3. TOKYO NIGHT THEME ---
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.policy.images = 'smart'
# Tabs
c.colors.tabs.bar.bg = '#1a1b26'
c.colors.tabs.even.bg = '#1a1b26'
c.colors.tabs.odd.bg = '#1a1b26'
c.colors.tabs.selected.even.bg = '#1f2335'
c.colors.tabs.selected.odd.bg = '#1f2335'
c.colors.tabs.selected.even.fg = '#c0caf5'
c.colors.tabs.selected.odd.fg = '#c0caf5'
c.colors.tabs.indicator.start = '#7aa2f7'
c.colors.tabs.indicator.stop = '#bb9af7'
# Status Bar
c.colors.statusbar.normal.bg = '#1a1b26'
c.colors.statusbar.normal.fg = '#c0caf5'
c.colors.statusbar.insert.bg = '#9ece6a'
c.colors.statusbar.insert.fg = '#15161e'
c.colors.statusbar.passthrough.bg = '#bb9af7'
c.colors.statusbar.command.bg = '#1a1b26'
c.colors.statusbar.command.fg = '#c0caf5'
c.colors.statusbar.url.success.http.fg = '#c0caf5'
c.colors.statusbar.url.success.https.fg = '#9ece6a'
# Hints
c.colors.hints.bg = '#e0af68'
c.colors.hints.fg = '#15161e'
c.colors.hints.match.fg = '#f7768e'

# --- 4. KEYBINDINGS (NEOVIM STYLE) ---
config.unbind('<Ctrl-v>') 
c.bindings.key_mappings['<Space>'] = '<Space>' 

# -- Targeted Search (New Tab) --
config.bind('<Ctrl-o>b', 'set-cmd-text -s :open -t b ') 
config.bind('<Ctrl-o>d', 'set-cmd-text -s :open -t d ') 
config.bind('<Ctrl-o>w', 'set-cmd-text -s :open -t w ') 
config.bind('<Ctrl-o>r', 'set-cmd-text -s :open -t r ') 
config.bind('<Ctrl-o>y', 'set-cmd-text -s :open -t y ') 
config.bind('<Ctrl-o>a', 'set-cmd-text -s :open -t a ')

# -- Standard Opening --
config.bind('o', 'set-cmd-text -s :open ') # Current Tab
config.bind('t', 'set-cmd-text -s :open -t ') # New Tab
config.bind('O', 'set-cmd-text -s :open -t ') # New Tab (Legacy Vim)

# -- Navigation --
config.bind('H', 'back')
config.bind('L', 'forward')
config.bind('J', 'tab-next')
config.bind('K', 'tab-prev')
config.bind('x', 'tab-close')
config.bind('X', 'undo') 
config.bind('d', 'scroll-page 0 0.5') 
config.bind('u', 'scroll-page 0 -0.5')

# -- Command & Modes --
config.bind(':', 'set-cmd-text :')
config.bind(';', 'set-cmd-text :')

# -- Yanking --
config.bind('yy', 'yank')
config.bind('yt', 'yank title')
config.bind('yd', 'yank domain')

# -- Hints --
config.bind('f', 'hint')
config.bind('F', 'hint links tab-bg') # Open in background

# -- External Editor (Edit text boxes in Neovim) --
c.editor.command = ["alacritty", "-e", "nvim", "{file}"]
config.bind('<Ctrl-e>', 'edit-text', mode='insert')

# -- Macros --
config.bind('<Ctrl-n>v', 'open -t https://github.com/neovim/neovim')
config.bind(',m', 'spawn --detach mpv {url}')
config.bind(',M', 'hint links spawn --detach mpv {hint-url}')
