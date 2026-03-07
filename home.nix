{ config, pkgs, inputs, ... }:

{
  home.username = "legend";
  home.homeDirectory = "/home/legend";
  home.stateVersion = "25.11"; # Bumped to 2026 freshness—docs say don't touch unless upgrading, but we're future-proofed

  # Expanded red team / cybersec arsenal: Pivot like a pro
  home.packages = with pkgs; [
    # Essentials: Fuzzy-recon and monitoring
    git tmux htop btop ripgrep fd fzf

    # Core exploits: Scan, crack, inject
    nmap metasploit burpsuite hashcat john wireshark-qt ghidra-bin sqlmap ffuf

    # Extra payloads: Reverse, MITM, C2, wifi chaos, mobile fuzz
    radare2 bettercap aircrack-ng empire responder android-tools
  ];

  # NixVim supremacy: Ditch vanilla neovim for modular lua configs—declarative dotfiles ftw
  programs.nixvim = {
    enable = true;
    default = true; # Set as $EDITOR
    viAlias = true;
    vimAlias = true;

    # Stub for your init.lua vibes—expand with modules (e.g., plugins.telescope.enable = true;)
    # Check NixVim docs for lsp, treesitter, etc.—it's like lazy.nvim but Nix-ified
    options = {
      number = true; # Line numbers for vuln line-hopping
      relativenumber = true;
      shiftwidth = 2;
    };

    # Example module: Treesitter for syntax pwnage
    plugins.treesitter.enable = true;

    # Raw lua inject: Slip in your custom snippets
    extraLuaConfig = ''
      -- Your lua sorcery here, like require('lspconfig').rust_analyzer.setup{}
    '';
  };

  # Home-Manager self-management: Because who needs root for userland?
  programs.home-manager.enable = true;
} 