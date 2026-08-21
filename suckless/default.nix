# Shared package set: the legenddots suckless tools, each rebuilt against our
# own config.h. Imported by both flake.nix and home.nix.
#
#   nix-build ./suckless -A st        # (with <nixpkgs>)
{ pkgs }:

let
  # Drop our config.h into a suckless source tree before it builds. suckless
  # Makefiles only run `cp config.def.h config.h` when config.h is absent, so a
  # file placed here in postPatch is what the build compiles against.
  withConfig = pkg: cfg:
    pkg.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        cp ${cfg} config.h
      '';
    });
in
{
  st    = withConfig pkgs.st    ./st/config.h;
  slock = withConfig pkgs.slock ./slock/config.h;
  dmenu = withConfig pkgs.dmenu ./dmenu/config.h;
  dwm   = withConfig pkgs.dwm   ./dwm/config.h;
  dwl   = withConfig pkgs.dwl   ./dwl/config.h;
  surf  = withConfig pkgs.surf  ./surf/config.h;
}
