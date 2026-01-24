{
  description = "Legend's Cybersec & Gentoo-inspired NixOS Flake";

  inputs = {
    # Using unstable because cybersec tools in stable are basically legacy code
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      # Define your host here. Change 'legend-box' to your actual hostname.
      lib = nixpkgs.lib;
    in {
      nixosConfigurations.legend-box = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix # Your main system config
          
          # Integrate Home Manager as a NixOS module
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.legend = import ./home.nix;
          }

          # Define the user 'legend' globally
          ({ pkgs, ... }: {
            users.users.legend = {
              isNormalUser = true;
              extraGroups = [ "wheel" "networkmanager" "video" "docker" "wireshark" ];
              shell = pkgs.zsh; # Every self-respecting nerd uses zsh or fish
            };
          })
        ];
      };
    };
}