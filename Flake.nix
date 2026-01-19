{
  description = "LegenDdots - A hardened, Lua-powered identity configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };
      in
      {
        # Home Manager configuration
        homeConfigurations = {
          "legenddots" = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              config = { allowUnfree = true; };
            };
            
            modules = [
              {
                # Enable home-manager
                programs.home-manager.enable = true;
                
                # Install packages
                home.packages = with pkgs; [
                  neovim
                  zsh
                  alacritty
                  git
                  curl
                  wget
                  ripgrep
                  fd
                  fzf
                  python3
                  nodejs
                  rustc
                  cargo
                  nmap
                  firefox
                  mpv
                  w3m
                  lazygit
                  jetbrains-mono
                  python3Packages.textual
                  python3Packages.httpx
                  python3Packages.beautifulsoup4
                  python3Packages.html2text
                  python3Packages.pyqt6
                  python3Packages.pyqt6-webengine
                ];

                # Configure Neovim
                programs.neovim = {
                  enable = true;
                  extraLuaConfig = builtins.readFile ./init.lua;
                  
                  # Install plugins
                  plugins = with pkgs.vimPlugins; [
                    tokyonight-nvim
                    which-key-nvim
                    dashboard-nvim
                    lazygit-nvim
                    telescope-nvim
                    nvim-treesitter
                    nvim-lualine
                  ];
                };

                # Configure Zsh
                programs.zsh = {
                  enable = true;
                  enableCompletion = true;
                  enableAutosuggestions = true;
                  enableSyntaxHighlighting = true;
                  
                  initExtra = builtins.readFile ./.zshrc;
                };

                # Configure Alacritty
                programs.alacritty = {
                  enable = true;
                  settings = {
                    # Import settings from alacritty.toml
                    import = [ ./alacritty.toml ];
                  };
                };

                # Link scripts
                home.file = {
                  ".local/bin/browser".source = ./scripts/browser;
                  ".local/bin/legend-gui".source = ./scripts/legend-gui;
                  ".local/bin/qute-config.py".source = ./scripts/qute-config.py;
                };

                # Install mommy if not present
                home.activation = {
                  installMommy = home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    if ! command -v mommy &> /dev/null; then
                      echo "Installing mommy..."
                      ${pkgs.writeShellScript "install-mommy" ''
                        ${builtins.readFile ./install_mommy.sh}
                      }
                    fi
                  '';
                };

                # Set home state version
                home.stateVersion = "23.11";
              }
            ];
          };
        };

        # Dev shell for development
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            neovim
            zsh
            alacritty
            git
            curl
            wget
            ripgrep
            fd
            fzf
            python3
            nodejs
            rustc
            cargo
            nmap
            firefox
            mpv
            w3m
            lazygit
            jetbrains-mono
            python3Packages.textual
            python3Packages.httpx
            python3Packages.beautifulsoup4
            python3Packages.html2text
            python3Packages.pyqt6
            python3Packages.pyqt6-webengine
          ];
        };
      });
}
