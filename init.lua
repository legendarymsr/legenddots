-- ==========================================================================
-- Legend@Yuki // RED TEAM COMMAND & CONTROL v24.0 [THE INPUT FIX]
-- ==========================================================================

-- 0. ENV FIX
vim.env.DISPLAY = ":0"
vim.g.mapleader = " "

-- 1. BOOTSTRAP
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 2. PLUGINS
require("lazy").setup({
  { "folke/tokyonight.nvim", config = function() vim.cmd[[colorscheme tokyonight-night]] end },
  { "altermo/nxwm", branch = "x11" },
  { "nvimdev/dashboard-nvim", config = function() 
      require('dashboard').setup({ theme = 'doom', config = { header = {"F U C K  V S  C O D E"}, 
      center = {{ icon = '󱂬 ', desc = 'Ignite WM', action = 'NXWMStart', key = 'w' }} }}) 
    end 
  },
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
})

-- 3. THE "NOT-DEAD" START COMMAND
vim.api.nvim_create_user_command("NXWMStart", function()
  local ok, nxwm = pcall(require, "nxwm")
  if ok then
    -- We use a small delay to ensure the X server has finished mapping the keyboard
    vim.defer_fn(function()
      nxwm.start()
      print("🚀 Engine Ignited. Use <leader>r to run.")
    end, 100)
  else
    print("❌ Run :Lazy sync first!")
  end
end, {})

-- 4. EMERGENCY KEYMAPS (If you get stuck)
-- This tries to force nvim back into a usable state
vim.keymap.set("n", "<Esc><Esc>", "<cmd>nohlsearch<CR>", { silent = true })

-- LAUNCHER
vim.keymap.set("n", "<leader>r", function()
  local cmd = vim.fn.input("Run: ")
  if cmd ~= "" then vim.cmd("!DISPLAY=:0 " .. cmd .. " &") end
end)