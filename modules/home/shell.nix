{ ... }:

{
  programs.zsh = {
    enable = true;

    autosuggestion.enable     = true;
    syntaxHighlighting.enable = true;

    history = {
      size       = 10000;
      save       = 10000;
      ignoreDups = true;
      share      = true;
    };

    shellAliases = {
      ll  = "ls -lah";
      cat = "bat";
      vim = "nvim";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[>](bold green)";
        error_symbol   = "[>](bold red)";
      };
    };
  };
}
