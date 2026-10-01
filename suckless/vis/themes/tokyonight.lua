-- SPDX-License-Identifier: GPL-3.0-or-later
-- ~/.config/vis/themes/tokyonight.lua — legenddots
--
-- Tokyo Night, done in the 16 ANSI color NAMES rather than hex. vis renders
-- these through the terminal's own palette — and our terminal IS Tokyo Night
-- (termux/colors.properties, suckless/st/config.h) — so `blue` = #7aa2f7,
-- `green` = #9ece6a, `magenta` = #bb9af7, etc. This works on every vis build
-- (including name-only ones that ignore `fore:#rrggbb`), and stays in lockstep
-- with the terminal theme. STYLE_DEFAULT='' keeps the terminal's bg/fg.

local lexers = vis.lexers

-- syntax
lexers.STYLE_DEFAULT       = ''
lexers.STYLE_NOTHING       = ''
lexers.STYLE_COMMENT       = 'fore:white,italics'  -- readable; italic sets it apart
lexers.STYLE_KEYWORD       = 'fore:magenta'      -- purple
lexers.STYLE_FUNCTION      = 'fore:blue'
lexers.STYLE_DEFINITION    = 'fore:blue'
lexers.STYLE_CLASS         = 'fore:cyan'
lexers.STYLE_TYPE          = 'fore:cyan'
lexers.STYLE_STRING        = 'fore:green'
lexers.STYLE_NUMBER        = 'fore:yellow'
lexers.STYLE_CONSTANT      = 'fore:yellow'
lexers.STYLE_OPERATOR      = 'fore:cyan'
lexers.STYLE_PREPROCESSOR  = 'fore:cyan'
lexers.STYLE_LABEL         = 'fore:magenta'
lexers.STYLE_REGEX         = 'fore:green'
lexers.STYLE_TAG           = 'fore:red'
lexers.STYLE_ATTRIBUTE     = 'fore:blue'
lexers.STYLE_VARIABLE      = ''
lexers.STYLE_IDENTIFIER    = ''
lexers.STYLE_HEADING       = 'fore:magenta,bold'
lexers.STYLE_EMBEDDED      = 'fore:cyan'
lexers.STYLE_ERROR         = 'fore:red,italics'
lexers.STYLE_WHITESPACE    = ''

-- editor UI
lexers.STYLE_LINENUMBER        = 'fore:blue'
lexers.STYLE_LINENUMBER_CURSOR = 'fore:white'
lexers.STYLE_CURSOR            = 'reverse'
lexers.STYLE_CURSOR_PRIMARY    = 'reverse'
lexers.STYLE_CURSOR_LINE       = ''
lexers.STYLE_COLOR_COLUMN      = 'back:black'
lexers.STYLE_SELECTION         = 'back:black,bold'
lexers.STYLE_STATUS            = 'fore:white,back:black'
lexers.STYLE_STATUS_FOCUSED    = 'fore:white,back:black,bold'
lexers.STYLE_SEPARATOR         = ''
lexers.STYLE_INFO              = 'bold'
lexers.STYLE_EOF               = ''

-- Diff
lexers.STYLE_ADDITION = 'fore:green'
lexers.STYLE_DELETION = 'fore:red'
lexers.STYLE_CHANGE   = 'fore:yellow'

-- Markdown / prose
lexers.STYLE_BOLD      = 'bold'
lexers.STYLE_ITALIC    = 'italics'
lexers.STYLE_LINK      = 'fore:blue'
lexers.STYLE_LIST      = 'fore:magenta'
lexers.STYLE_CODE      = 'fore:cyan'
