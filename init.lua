
-- ==========================================================================
-- Legend@Yuki // RED TEAM COMMAND & CONTROL v23.0 [THE FINAL FIX]
-- ==========================================================================

-- 0. FORCE ENVIRONMENT (Fixes the "Nothing opens" bug)
vim.env.DISPLAY = ":0"
vim.g.mapleader = " "

-- 1. BOOTSTRAP LAZY.NVIM
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 2. SYSTEM HARDENING
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.cursorline = true
vim.opt.laststatus = 3
vim.opt.timeoutlen = 300
vim.opt.clipboard = "unnamedplus"

-- 3. THE PLUGINS
require("lazy").setup({
  -- THEME
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ style = "night", transparent = false, terminal_colors = true })
      vim.cmd[[colorscheme tokyonight-night]]
    end,
  },

  -- THE DASHBOARD
  {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    config = function()
      require('dashboard').setup({
        theme = 'doom',
        config = {
          header = {
            [[                                                       ]],
            [[  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗   ]],
            [[  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║   ]],
            [[  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║   ]],
            [[  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║   ]],
            [[  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║   ]],
            [[  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝   ]],
            [[                (   Neovim, BTW   )                    ]],
            [[                                                       ]],
            [[              +-------------------------+              ]],
            [[              |         F U C K         |              ]],
            [[              |      V S   C O D E      |              ]],
            [[              +-------------------------+              ]],
            [[                                                       ]],
          },
          center = {
            { icon = '󰊄 ', desc = 'Find Files       ', action = 'Telescope find_files', key = 'f' },
            { icon = '󱂬 ', desc = 'Ignite WM         ', action = 'NXWMStart', key = 'w' },
            { icon = ' ', desc = 'LFS Book         ', action = 'vsplit | terminal w3m https://www.linuxfromscratch.org/lfs/view/stable/', key = 'l' },
            { icon = ' ', desc = 'The Lab (Git)    ', action = 'LazyGit', key = 'g' },
            { icon = ' ', desc = 'Identity Config  ', action = 'e $MYVIMRC', key = 'c' },
            { icon = '󰓾 ', desc = 'Scan Network     ', action = 'ReconLocal', key = 'n' },
          },
          footer = { "Mommy's talented little operator is live~" },
        },
      })
    end,
    dependencies = { {'nvim-tree/nvim-web-devicons'}}
  },

  -- THE WINDOW MANAGER (Correct Repo/Module)
  {
    "altermo/nxwm",
    branch = "x11",
    config = function()
      require("nxwm").setup({
        autofocus = true,
        verbal = true,
      })
    end,
  },

  -- TOOLS
  { "kdheepak/lazygit.nvim", cmd = { "LazyGit" } },
  { 'nvim-telescope/telescope.nvim', tag = '0.1.8', dependencies = { 'nvim-lua/plenary.nvim' } },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { 'nvim-lualine/lualine.nvim', config = function() require('lualine').setup({ options = { theme = 'tokyonight' } }) end },
  { "folke/which-key.nvim", event = "VeryLazy", config = function() require("which-key").setup() end },
})

-- 4. CUSTOM LOGIC
vim.api.nvim_create_user_command("NXWMStart", function()
  local ok, nxwm = pcall(require, "nxwm")
  if ok then
    nxwm.start()
    print("🚀 [NXWM] Engine Ignited. Use <leader>r to launch programs.")
  else
    print("❌ [ERROR] nxwm module not found. Run :Lazy sync")
  end
end, {})

vim.api.nvim_create_user_command("ReconLocal", function()
  vim.cmd("vsplit | terminal nmap -sn 192.168.1.0/24")
end, {})

-- 5. KEYMAPS (THE FOOLPROOF ONES)
-- Start WM
vim.keymap.set("n", "<leader>wm", ":NXWMStart<CR>", { desc = "Start WM" })

-- RUN APPS (The Fix)
vim.keymap.set("n", "<leader>r", function()
  local cmd = vim.fn.input("🔥 Launch App: ")
  if cmd ~= "" then
    -- We force the DISPLAY variable into the shell command itself
    vim.cmd("!DISPLAY=:0 " .. cmd .. " &")
  end
end, { desc = "Run X11 Program" })

-- EDIT CONFIG
vim.keymap.set("n", "<leader>sc", "<cmd>e $MYVIMRC<CR>", { desc = "Open Config" })

-- QUICK TERMINAL
vim.keymap.set("n", "<leader>t", ":vsplit | term<CR>i", { desc = "Terminal" })