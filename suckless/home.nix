# Home-manager module for the legenddots suckless tools.
#
# Flake users get this as `homeManagerModules.default`. Non-flake users can
# import the file directly:
#
#   imports = [ ./suckless/home.nix ];
#   legend.suckless.enable = true;
{ config, lib, pkgs, ... }:

let
  cfg = config.legend.suckless;
  suckless = import ./default.nix { inherit pkgs; };
in
{
  options.legend.suckless = {
    enable = lib.mkEnableOption "legenddots suckless tools (st, slock, dmenu, dwm, dwl, surf)";

    tools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = builtins.attrValues suckless;
      defaultText = "all of st, slock, dmenu, dwm, dwl, surf";
      description = "Which suckless tools to install (each built with our config.h).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = cfg.tools;
  };
}
