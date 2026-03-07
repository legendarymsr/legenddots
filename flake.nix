{
  description = "Legend's Cybersec & Gentoo-inspired NixOS Flake";

  inputs = {
    # Unstable for those fresh exploits—stable's for normies hoarding CVE-0days from last year
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixVim: Neovim's declarative doppelgänger—lua configs as Nix modules, reproducible pwnage
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
    in {
      nixosConfigurations.legend-box = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix # Your main system config—add hardening here (see below)

          # Home-Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.legend = import ./home.nix;
          }

          # NixVim as HM module—like injecting a lua rootkit into your editor
          nixvim.homeManagerModules.nixvim

          # Global user config: Legend as sudoer, zsh shell, groups for virt pivots and packet sniffs
          ({ pkgs, ... }: {
            users.users.legend = {
              isNormalUser = true;
              extraGroups = [ "wheel" "networkmanager" "video" "docker" "wireshark" "libvirt" ];
              shell = pkgs.zsh;
            };

            # Hardening: Passwordless sudo for wheel—quick escalations, but audit your opsec
            security.sudo.wheelNeedsPassword = false;

            # Fail2ban: Swat those SSH brute-forcers like rm -rf on logs
            services.fail2ban.enable = true;

            # Firewall: Locked down, poke holes for metasploit listeners as needed
            networking.firewall.enable = true;

            # Hardened kernel: Shrug off exploits like a grsecurity patch
            boot.kernelPackages = pkgs.linuxPackages_hardened;

            # AppArmor: Confine apps like SELinux on steroids
            security.apparmor.enable = true;
          })
        ];
      };
    };
}