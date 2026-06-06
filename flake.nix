{
  description = "Legend's Cybersec NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs   = nixpkgs.legacyPackages.${system};
      lib    = nixpkgs.lib;
    in {
      nixosConfigurations.legend-box = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/legend-box
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs    = true;
            home-manager.useUserPackages  = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.legend.imports = [
              nixvim.homeManagerModules.nixvim
              ./hosts/legend-box/home.nix
            ];
          }
        ];
      };

      nixosConfigurations.nixos-btw = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixos-btw
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs    = true;
            home-manager.useUserPackages  = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.legend.imports = [
              nixvim.homeManagerModules.nixvim
              ./hosts/nixos-btw/home.nix
            ];
          }
        ];
      };

      homeConfigurations."legend@legend-box" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          nixvim.homeManagerModules.nixvim
          ./hosts/legend-box/home.nix
        ];
      };

      devShells.${system}.pentest = import ./shells/pentest.nix { inherit pkgs; };
    };
}
