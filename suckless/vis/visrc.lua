-- ~/.config/vis/visrc.lua — legenddots
--
-- vis: modal editing (vi keys) + Plan 9 structural regular expressions (sam),
-- configured in *Lua* — a real language, not a bespoke config DSL. This file is
-- the whole config; edit it and restart vis, no recompile. This is why vis
-- replaced vim here: same job, no Vimscript.

require('vis')

vis.events.subscribe(vis.events.INIT, function()
	-- Tokyo Night, matching st/dwm (themes/tokyonight.lua → ~/.config/vis/themes/).
	vis:command('set theme tokyonight')
end)

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	vis:command('set number')       -- line numbers
	vis:command('set autoindent')   -- keep indent on newline
	vis:command('set expandtab')    -- spaces, not tabs
	vis:command('set tabwidth 4')   -- ...four of them
	vis:command('set colorcolumn 80')
end)

-- Optional C/C++ LSP — the vis-native replacement for the old c-lsp.vim. Clone
-- vis-lspc into ~/.config/vis/ (git clone https://gitlab.com/muhq/vis-lspc) and
-- uncomment; it drives clangd, no node/python/plugin-manager:
-- local lspc = require('vis-lspc')
-- lspc.autostart = true
