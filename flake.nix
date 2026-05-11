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
          ./configuration.nix
          ./system.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.legend = {
              imports = [
                nixvim.homeManagerModules.nixvim
                ./home.nix
              ];
            };
          }
        ];
      };

      devShells.${system}.pentest = pkgs.mkShell {
        name = "pentest";
        packages = with pkgs; [
          metasploit  # exploitation framework
          burpsuite   # web proxy / scanner
          ghidra      # reverse engineering
          hashcat     # GPU password cracking
        ];
        shellHook = ''
          echo "pentest shell — metasploit  burpsuite  ghidra  hashcat"
        '';
      };
    };
}
