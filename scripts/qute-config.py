# LEGEND QUTEBROWSER CONFIG
config.load_autoconfig(False)

# Core
c.content.javascript.enabled = True
c.scrolling.smooth = True
c.content.blocking.method = 'both'
c.fonts.default_family = 'JetBrainsMono Nerd Font'
c.fonts.default_size = '11pt'
c.editor.command = ["alacritty", "-e", "nvim", "{file}"]

# Search engines
c.url.searchengines = {
    'DEFAULT': 'https://search.brave.com/search?q={}',
    'b': 'https://search.brave.com/search?q={}',
    'd': 'https://duckduckgo.com/?q={}',
    'w': 'https://en.wikipedia.org/w/index.php?search={}',
    'r': 'https://search.brave.com/search?q=site:reddit.com+{}',
    'g': 'https://wiki.gentoo.org/index.php?search={}&title=Handbook%3AAMD64',
    'y': 'https://www.youtube.com/results?search_query={}',
    'a': 'https://wiki.archlinux.org/?search={}',
}

# Tokyo Night
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.policy.images = 'smart'
c.colors.tabs.bar.bg = '#1a1b26'
c.colors.tabs.even.bg = '#1a1b26'
c.colors.tabs.odd.bg = '#1a1b26'
c.colors.tabs.selected.even.bg = '#1f2335'
c.colors.tabs.selected.odd.bg = '#1f2335'
c.colors.tabs.selected.even.fg = '#c0caf5'
c.colors.tabs.selected.odd.fg = '#c0caf5'
c.colors.tabs.indicator.start = '#7aa2f7'
c.colors.tabs.indicator.stop = '#bb9af7'
c.colors.statusbar.normal.bg = '#1a1b26'
c.colors.statusbar.normal.fg = '#c0caf5'
c.colors.statusbar.insert.bg = '#9ece6a'
c.colors.statusbar.insert.fg = '#15161e'
c.colors.statusbar.passthrough.bg = '#bb9af7'
c.colors.statusbar.command.bg = '#1a1b26'
c.colors.statusbar.command.fg = '#c0caf5'
c.colors.statusbar.url.success.http.fg = '#c0caf5'
c.colors.statusbar.url.success.https.fg = '#9ece6a'
c.colors.hints.bg = '#e0af68'
c.colors.hints.fg = '#15161e'
c.colors.hints.match.fg = '#f7768e'

# Keybinds
config.unbind('<Ctrl-v>')
c.bindings.key_mappings['<Space>'] = '<Space>'

config.bind('o', 'set-cmd-text -s :open ')
config.bind('t', 'set-cmd-text -s :open -t ')
config.bind('H', 'back')
config.bind('L', 'forward')
config.bind('J', 'tab-next')
config.bind('K', 'tab-prev')
config.bind('x', 'tab-close')
config.bind('X', 'undo')
config.bind('d', 'scroll-page 0 0.5')
config.bind('u', 'scroll-page 0 -0.5')
config.bind(';', 'set-cmd-text :')
config.bind('yy', 'yank')
config.bind('yt', 'yank title')
config.bind('yd', 'yank domain')
config.bind('f', 'hint')
config.bind('F', 'hint links tab-bg')
config.bind('<Ctrl-e>', 'edit-text', mode='insert')
config.bind(',m', 'spawn --detach mpv {url}')
config.bind(',M', 'hint links spawn --detach mpv {hint-url}')

# Search shortcuts (new tab)
for key in ['b', 'd', 'w', 'r', 'y', 'a', 'g']:
    config.bind(f'<Ctrl-o>{key}', f'set-cmd-text -s :open -t {key} ')
