{ ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
    };

    plugins.treesitter.enable = true;

    extraLuaConfig = ''
      -- custom lua config here
    '';
  };
}
