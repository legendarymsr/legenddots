{ ... }:

{
  programs.nixvim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;

    opts = {
      number         = true;
      relativenumber = true;
      shiftwidth     = 2;
    };

    plugins.treesitter.enable = true;

    plugins.lsp = {
      enable = true;
      servers = {
        lua_ls.enable        = true;
        pyright.enable       = true;
        bashls.enable        = true;
        nixd.enable          = true;
        rust_analyzer.enable = true;
      };
      keymaps = {
        diagnostic = {
          "<leader>dd" = "open_float";
          "[d"         = "goto_prev";
          "]d"         = "goto_next";
        };
        lspBuf = {
          gd           = "definition";
          gr           = "references";
          gi           = "implementation";
          K            = "hover";
          "<leader>rn" = "rename";
          "<leader>ca" = "code_action";
        };
      };
    };

    plugins.cmp = {
      enable = true;
      settings = {
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "buffer"; }
        ];
        snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
        mapping = {
          "<C-Space>" = "cmp.mapping.complete()";
          "<CR>"      = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = ''
            cmp.mapping(function(fallback)
              if cmp.visible() then cmp.select_next_item()
              elseif require("luasnip").expand_or_jumpable() then require("luasnip").expand_or_jump()
              else fallback() end
            end, { "i", "s" })
          '';
          "<S-Tab>" = ''
            cmp.mapping(function(fallback)
              if cmp.visible() then cmp.select_prev_item()
              else fallback() end
            end, { "i", "s" })
          '';
        };
      };
    };

    plugins.luasnip.enable   = true;
    plugins.cmp-nvim-lsp.enable = true;
    plugins.cmp-buffer.enable   = true;
    plugins.cmp_luasnip.enable  = true;

    extraLuaConfig = ''
      vim.diagnostic.config({
        virtual_text    = { prefix = "●" },
        signs           = true,
        underline       = true,
        update_in_insert = false,
        severity_sort   = true,
        float           = { border = "rounded", source = true },
      })

      vim.keymap.set("n", "<leader>dl", "<cmd>Telescope diagnostics<cr>", { desc = "Diagnostics list" })
    '';
  };
}
