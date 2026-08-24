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

-- GUI-like feel (terminal nvim, but behaves like a graphical IDE)
vim.opt.mouse = "a"               -- full mouse: click, drag-select, scroll, resize splits
vim.opt.mousemoveevent = true     -- hover events (bufferline close buttons, etc.)
vim.opt.signcolumn = "yes"        -- always-on gutter (git/diagnostics) — no text jump
vim.opt.scrolloff = 8             -- keep context around the cursor
vim.opt.smoothscroll = true       -- smooth <C-d>/<C-u> on wrapped lines (0.10+)
vim.opt.pumblend = 10             -- slight transparency on the completion popup
vim.opt.pumheight = 12            -- cap popup height
vim.opt.winminwidth = 5
vim.opt.splitkeep = "screen"
vim.opt.title = true              -- set the terminal window title to the file
vim.opt.fillchars = { eob = " ", fold = " ", foldopen = "▾", foldsep = " ", foldclose = "▸" }

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
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "python", "lua", "bash", "nix", "rust", "zig", "c", "cpp", "c_sharp",
          "vim", "vimdoc", "markdown", "markdown_inline", "json", "toml", "yaml",
        },
        auto_install = true,                -- pull a parser on demand (needs a C compiler)
        highlight = { enable = true },       -- the actual syntax colouring
        indent = { enable = true },
      })
    end,
  },
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

  -- LSP + COMPLETION (built-in LSP, Neovim 0.11+)
  {
    "williamboman/mason.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",           -- ships the lsp/<server>.lua definitions
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      require("mason").setup()

      -- Install the LSP binaries via mason's registry, by MASON package name.
      -- (mason-lspconfig's ensure_installed validates lspconfig names and rejects
      --  entries like "nixd"/"zls" across versions — this sidesteps that entirely.)
      local mr = require("mason-registry")
      local packages = {
        "lua-language-server", "pyright", "bash-language-server",
        "nixd", "rust-analyzer", "zls",
        "clangd", "omnisharp",   -- C / C++ (clangd) and C# (omnisharp)
      }
      local function install_missing()
        for _, name in ipairs(packages) do
          local ok, pkg = pcall(mr.get_package, name)
          if ok and not pkg:is_installed() then pkg:install() end
        end
      end
      -- mason ships prebuilt glibc Linux binaries; they don't run on Termux/
      -- Android (bionic libc). Skip auto-install there — install servers with
      -- `pkg`/`npm`/`pip` instead and vim.lsp.enable picks them up from PATH.
      if os.getenv("TERMUX_VERSION") then
        -- Termux: mason auto-install skipped (see above).
      elseif mr.refresh then
        mr.refresh(install_missing)
      else
        install_missing()
      end

      vim.lsp.config("*", { capabilities = require("cmp_nvim_lsp").default_capabilities() })

      -- Teach lua_ls about the Neovim runtime: `vim` is a known global (no more
      -- "Undefined global `vim`" spam) and the nvim API gets completion/docs.
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local buf = ev.buf
          local map = function(k, v, d)
            vim.keymap.set("n", k, v, { buffer = buf, desc = d })
          end
          map("gd",         vim.lsp.buf.definition,    "Go to definition")
          map("gr",         vim.lsp.buf.references,    "References")
          map("gi",         vim.lsp.buf.implementation,"Go to implementation")
          map("K",          vim.lsp.buf.hover,         "Hover docs")
          map("<leader>rn", vim.lsp.buf.rename,        "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action,   "Code action")
          map("<leader>dd", vim.diagnostic.open_float, "Diagnostics float")
          map("[d",         function() vim.diagnostic.jump({ count = -1 }) end, "Prev diagnostic")
          map("]d",         function() vim.diagnostic.jump({ count = 1 })  end, "Next diagnostic")
          map("<leader>dl", "<cmd>Telescope diagnostics<cr>", "Diagnostics list")
        end,
      })

      vim.lsp.enable({ "lua_ls", "pyright", "bashls", "nixd", "rust_analyzer", "zls",
                       "clangd", "omnisharp" })

      vim.diagnostic.config({
        virtual_text    = { prefix = "●" },
        signs           = true,
        underline       = true,
        update_in_insert = false,
        severity_sort   = true,
        float           = { border = "rounded", source = true },
      })

      local cmp     = require("cmp")
      local luasnip = require("luasnip")
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
        },
      })
    end,
  },

  -- ======================================================================
  -- GUI-LIKE EYE CANDY — terminal nvim that feels like a graphical IDE
  -- ======================================================================

  -- Buffer tabs across the top (like GUI editor tabs)
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          separator_style = "slant",
          offsets = { { filetype = "NvimTree", text = "Files", separator = true } },
        },
      })
    end,
    keys = {
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
    },
  },

  -- Fancy cmdline / messages / LSP popups + notifications (the big GUI feel)
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    config = function()
      require("notify").setup({ background_colour = "#1a1b26", stages = "fade_in_slide_out", timeout = 2500 })
      vim.notify = require("notify")
      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
        presets = {
          bottom_search = true,       -- classic bottom /search
          command_palette = true,     -- centered cmdline + popupmenu (GUI palette)
          long_message_to_split = true,
          lsp_doc_border = true,
        },
      })
    end,
  },

  -- Indentation guides + active-scope highlight
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "VeryLazy",
    config = function()
      require("ibl").setup({ indent = { char = "│" }, scope = { enabled = true, show_start = false } })
    end,
  },

  -- Git signs in the gutter (add / change / delete)
  { "lewis6991/gitsigns.nvim", event = "VeryLazy", config = function() require("gitsigns").setup() end },

  -- Prettier vim.ui.select / vim.ui.input popups (rename, code actions, …)
  { "stevearc/dressing.nvim", event = "VeryLazy" },

  -- Scrollbar with diagnostic + git marks (GUI-style gutter minimap)
  {
    "petertriho/nvim-scrollbar",
    event = "VeryLazy",
    dependencies = "lewis6991/gitsigns.nvim",
    config = function()
      require("scrollbar").setup()
      require("scrollbar.handlers.gitsigns").setup()
    end,
  },

  -- Smooth animated scrolling
  { "karb94/neoscroll.nvim", event = "VeryLazy", config = function() require("neoscroll").setup() end },
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