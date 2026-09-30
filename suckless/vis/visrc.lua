-- ~/.config/vis/visrc.lua — legenddots
--
-- vis: modal editing (vi keys) + Plan 9 structural regular expressions (sam),
-- configured in *Lua* — a real language, not a bespoke config DSL. This file is
-- the whole config; edit it and restart vis, no recompile. This is why vis
-- replaced vim here: same job, no Vimscript.

require('vis')

vis.events.subscribe(vis.events.INIT, function()
	-- Tokyo Night, matching st/dwm. NOTE: vis only searches its install theme
	-- dir ($PREFIX/share/vis/themes or /usr/share/vis/themes), NOT
	-- ~/.config/vis/themes — so tokyonight.lua must be linked into that dir (the
	-- installers do this). Then this fully applies (re-highlights everything).
	vis:command('set theme tokyonight')
end)

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	vis:command('set number')       -- line numbers
	vis:command('set autoindent')   -- keep indent on newline
	vis:command('set expandtab')    -- spaces, not tabs
	vis:command('set tabwidth 4')   -- ...four of them
	vis:command('set colorcolumn 80')
end)

-- Status line: mode · file[+] on the left; line:col and a Top/Bot/NN% ruler on
-- the right (vim's ruler, minus the DSL).
vis.events.subscribe(vis.events.WIN_STATUS, function(win)
	local modes = {
		[vis.modes.NORMAL]           = '',
		[vis.modes.OPERATOR_PENDING] = '',
		[vis.modes.VISUAL]           = 'VISUAL',
		[vis.modes.VISUAL_LINE]      = 'VISUAL-LINE',
		[vis.modes.INSERT]           = 'INSERT',
		[vis.modes.REPLACE]          = 'REPLACE',
	}
	local file, sel = win.file, win.selection
	local left, right = {}, {}

	local mode = modes[vis.mode]
	if mode and mode ~= '' and vis.win == win then table.insert(left, mode) end
	table.insert(left, (file.name or '[No Name]') .. (file.modified and ' [+]' or ''))

	table.insert(right, sel.line .. ':' .. sel.col)
	local total = #file.lines
	local pct
	if total <= 1 then           pct = 'All'
	elseif sel.line == 1 then     pct = 'Top'
	elseif sel.line == total then pct = 'Bot'
	else pct = string.format('%d%%', math.floor((sel.line - 1) / (total - 1) * 100)) end
	table.insert(right, pct)

	win:status(table.concat(left, ' » '), table.concat(right, ' « '))
end)

-- Optional C/C++ LSP — the vis-native replacement for the old c-lsp.vim. Clone
-- vis-lspc into ~/.config/vis/ (git clone https://gitlab.com/muhq/vis-lspc) and
-- uncomment; it drives clangd, no node/python/plugin-manager:
-- local lspc = require('vis-lspc')
-- lspc.autostart = true
