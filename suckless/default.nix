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
      # Ours first: some nixpkgs postPatch hooks (slock) sed config.h.
      postPatch = ''
        rm -f config.h
        cp ${cfg} config.h
        chmod u+w config.h
      '' + (old.postPatch or "");
    });
in
{
  st    = withConfig pkgs.st    ./st/config.h;
  slock = withConfig pkgs.slock ./slock/config.h;
  dmenu = withConfig pkgs.dmenu ./dmenu/config.h;
  dwm   = withConfig pkgs.dwm   ./dwm/config.h;
  # dwl >= 0.8 also wants an `axes` (scroll-wheel binding) table; Guix still
  # ships 0.7 where the Axis type doesn't exist, so add it here, not in config.h.
  dwl   = (withConfig pkgs.dwl ./dwl/config.h).overrideAttrs (old: {
    postPatch = old.postPatch + pkgs.lib.optionalString
      (pkgs.lib.versionAtLeast pkgs.dwl.version "0.8") ''
        chmod u+w config.h
        echo 'static const Axis axes[] = { { MODKEY, AxisUp, focusstack, {.i = -1} }, { MODKEY, AxisDown, focusstack, {.i = +1} } };' >> config.h
      '';
  });
  surf  = withConfig pkgs.surf  ./surf/config.h;
}
