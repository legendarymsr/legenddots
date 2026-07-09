-- ==========================================================================
-- Legend@Yuki // RED TEAM COMMAND & CONTROL v25.0 [STABILIZED]
-- ==========================================================================

-- 1. BOOTSTRAP LAZY.NVIM
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 2. SYSTEM HARDENING (The Fundamentals)
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.cursorline = true
vim.opt.laststatus = 3
vim.opt.timeoutlen = 300
vim.opt.clipboard = "unnamedplus" -- Sync with system clipboard for easy C&C
vim.opt.undofile = true           -- Persistent undo, even after restart

-- 3. THE PLUGINS
require("lazy").setup({
  -- THEME: TokyoNight (The classic Red Team glow)
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ 
        style = "night", 
        transparent = false, 
        terminal_colors = true 
      })
      vim.cmd[[colorscheme tokyonight-night]]
    end,
  },

  -- THE HUD
  { "folke/which-key.nvim", event = "VeryLazy", config = function() require("which-key").setup() end },

  -- THE DASHBOARD (Cleaned and re-tooled for pentesting)
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
            { icon = '󰊄 ', desc = 'Target Search    ', action = 'Telescope find_files', key = 'f' },
            { icon = '󱎸 ', desc = 'Recent Intel     ', action = 'Telescope oldfiles', key = 'r' },
            { icon = ' ', desc = 'The Lab (Git)    ', action = 'LazyGit', key = 'g' },
            { icon = ' ', desc = 'Identity Config  ', action = 'e $MYVIMRC', key = 'c' },
            { icon = '󰓾 ', desc = 'Scan Local Net   ', action = 'ReconLocal', key = 'n' },
            { icon = '󰒲 ', desc = 'Shutdown Neovim  ', action = 'qa', key = 'q' },
          },
          footer = { "Mommy's talented little operator is live~" },
        },
      })
    end,
    dependencies = { {'nvim-tree/nvim-web-devicons'}}
  },

  -- WEAPONRY
  { "kdheepak/lazygit.nvim", cmd = { "LazyGit" }, keys = { { "<leader>gg", "<cmd>LazyGit<CR>" } } },
  { 'nvim-telescope/telescope.nvim', tag = '0.1.8', dependencies = { 'nvim-lua/plenary.nvim' } },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  {
    'nvim-lualine/lualine.nvim',
    config = function() require('lualine').setup({ options = { theme = 'tokyonight' } }) end
  },
  
  -- FILE BROWSER
  {
    "nvim-tree/nvim-tree.lua",
    config = function() require("nvim-tree").setup() end,
    keys = { { "<leader>e", "<cmd>NvimTreeToggle<CR>" } }
  },
})

-- 4. RECON FUNCTIONS
vim.api.nvim_create_user_command("ReconLocal", function()
  vim.cmd("vsplit | terminal nmap -sn 192.168.1.0/24")
end, { desc = "Perform local network discovery" })

-- 5. THE TOKYO OVERRIDES (The Glow)
vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#bb9af7" }) 
vim.api.nvim_set_hl(0, "DashboardIcon", { fg = "#7aa2f7" })   
vim.api.nvim_set_hl(0, "DashboardKey", { fg = "#9ece6a" })    
vim.api.nvim_set_hl(0, "DashboardDesc", { fg = "#c0caf5" })   
vim.api.nvim_set_hl(0, "DashboardFooter", { fg = "#565f89" }) 

-- 6. KEYMAPS (Pure Efficiency)
vim.keymap.set("n", "<leader>sc", "<cmd>e $MYVIMRC<CR>", { desc = "Edit Config" })
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find Files" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Grep Intel" })
vim.keymap.set("n", "<leader>bb", "<cmd>Telescope buffers<cr>", { desc = "List Buffers" })

-- Terminal Shortcuts
vim.keymap.set("n", "<leader>t", ":vsplit | term<CR>i", { desc = "Open Terminal" })
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Escape Terminal Mode" })