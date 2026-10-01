{
  description = "legenddots suckless tools (st, slock, dmenu, dwm, dwl, surf) built with custom Tokyo Night config.h";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems f;
      sucklessFor = system: import ./default.nix { pkgs = nixpkgs.legacyPackages.${system}; };
    in
    {
      # Per-tool packages + a `default` bundling all six.
      #   nix build ./suckless#dwm
      #   nix profile install ./suckless#st
      packages = forAll (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          s = sucklessFor system;
        in
        s // {
          default = pkgs.buildEnv {
            name = "legend-suckless";
            paths = builtins.attrValues s;
          };
        });

      # Home-manager module:
      #   imports = [ inputs.suckless.homeManagerModules.default ];
      #   legend.suckless.enable = true;
      homeManagerModules.default = import ./home.nix;

      # A shell with the build deps for hacking on the configs by hand.
      #   nix develop ./suckless
      devShells = forAll (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = pkgs.mkShell {
            inputsFrom = builtins.attrValues (sucklessFor system);
            packages = [ pkgs.pkg-config pkgs.gnumake pkgs.gcc ];
          };
        });
    };
}
