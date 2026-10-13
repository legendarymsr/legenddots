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

    synfetch.url = "github:SXSLVT/synfetch";

    brave-origin = {
      url = "github:legendarymsr/brave-origin-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, synfetch, brave-origin, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs   = nixpkgs.legacyPackages.${system};
      lib    = nixpkgs.lib;

      # Shared home-manager wiring for every host (and the ISO).
      hmFor = home: {
        home-manager.useGlobalPkgs    = true;
        home-manager.useUserPackages  = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.legend.imports = [
          nixvim.homeManagerModules.nixvim
          home
        ];
      };
    in {
      nixosConfigurations.legend-box = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/legend-box
          brave-origin.nixosModules.brave-origin
          { programs.brave-origin.enable = true; }
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

      nixosConfigurations.macbook-air = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/macbook-air
          brave-origin.nixosModules.brave-origin
          { programs.brave-origin.enable = true; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs    = true;
            home-manager.useUserPackages  = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.legend.imports = [
              nixvim.homeManagerModules.nixvim
              ./hosts/macbook-air/home.nix
            ];
          }
        ];
      };

      nixosConfigurations.nixosbtw = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixosbtw
          brave-origin.nixosModules.brave-origin
          { programs.brave-origin.enable = true; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs    = true;
            home-manager.useUserPackages  = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.legend.imports = [
              nixvim.homeManagerModules.nixvim
              ./hosts/nixosbtw/home.nix
            ];
          }
        ];
      };

      # Live/installer ISO of legend-box (Hyprland + Brave Origin), hybrid
      # BIOS (syslinux) + UEFI (GRUB). Build:
      #   nix build .#nixosConfigurations.legend-iso.config.system.build.isoImage
      #   nix build .#legend-iso
      nixosConfigurations.legend-iso = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./hosts/iso
          brave-origin.nixosModules.brave-origin
          { programs.brave-origin.enable = true; }
          home-manager.nixosModules.home-manager
          (hmFor ./hosts/legend-box/home.nix)
        ];
      };

      # Suckless live ISO (dwm + st/dmenu/slock/dwl/surf with our config.h).
      #   nix build .#suckless-iso
      nixosConfigurations.suckless-iso = lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          home-manager.nixosModules.home-manager
          ./suckless/iso.nix
        ];
      };

      packages.${system} = {
        legend-iso   = self.nixosConfigurations.legend-iso.config.system.build.isoImage;
        suckless-iso = self.nixosConfigurations.suckless-iso.config.system.build.isoImage;
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
