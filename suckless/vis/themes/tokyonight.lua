-- ~/.config/vis/themes/tokyonight.lua — legenddots
-- Tokyo Night for vis, matching st/dwm (bg #1a1b26, fg #c0caf5, blue #7aa2f7).
-- Selected from visrc.lua with `set theme tokyonight`. Truecolor terminals (st).

local lexers = vis.lexers

-- syntax
lexers.STYLE_DEFAULT      = 'back:#1a1b26,fore:#c0caf5'
lexers.STYLE_NOTHING      = 'back:#1a1b26'
lexers.STYLE_COMMENT      = 'fore:#565f89,italics'
lexers.STYLE_KEYWORD      = 'fore:#bb9af7'
lexers.STYLE_FUNCTION     = 'fore:#7aa2f7'
lexers.STYLE_DEFINITION   = 'fore:#7aa2f7'
lexers.STYLE_CLASS        = 'fore:#2ac3de'
lexers.STYLE_TYPE         = 'fore:#2ac3de'
lexers.STYLE_STRING       = 'fore:#9ece6a'
lexers.STYLE_NUMBER       = 'fore:#ff9e64'
lexers.STYLE_CONSTANT     = 'fore:#ff9e64'
lexers.STYLE_OPERATOR     = 'fore:#89ddff'
lexers.STYLE_PREPROCESSOR = 'fore:#7dcfff'
lexers.STYLE_LABEL        = 'fore:#bb9af7'
lexers.STYLE_REGEX        = 'fore:#b4f9f8'
lexers.STYLE_TAG          = 'fore:#f7768e'
lexers.STYLE_ATTRIBUTE    = 'fore:#7aa2f7'
lexers.STYLE_VARIABLE     = 'fore:#c0caf5'
lexers.STYLE_IDENTIFIER   = 'fore:#c0caf5'
lexers.STYLE_EMBEDDED     = 'back:#1f2335'
lexers.STYLE_ERROR        = 'fore:#f7768e,italics'
lexers.STYLE_WHITESPACE   = 'fore:#414868'

-- editor UI
lexers.STYLE_LINENUMBER        = 'fore:#3b4261,back:#1a1b26'
lexers.STYLE_LINENUMBER_CURSOR = 'fore:#737aa2,back:#1a1b26'
lexers.STYLE_CURSOR            = 'fore:#1a1b26,back:#c0caf5'
lexers.STYLE_CURSOR_PRIMARY    = 'fore:#1a1b26,back:#c0caf5'
lexers.STYLE_CURSOR_LINE       = 'back:#292e42'
lexers.STYLE_COLOR_COLUMN      = 'back:#292e42'
lexers.STYLE_SELECTION         = 'back:#283457'
lexers.STYLE_STATUS            = 'fore:#545c7e,back:#16161e'
lexers.STYLE_STATUS_FOCUSED    = 'fore:#c0caf5,back:#16161e'
lexers.STYLE_SEPARATOR         = 'fore:#c0caf5'
lexers.STYLE_INFO              = 'fore:#c0caf5,back:#1a1b26'
lexers.STYLE_EOF               = 'fore:#414868'
