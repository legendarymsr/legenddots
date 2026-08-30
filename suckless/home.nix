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

    # Not suckless, but shipped alongside for the minimalist collection: minimal
    # screen + vi, configured via runtime dotfiles (~/.screenrc, ~/.exrc) rather
    # than a compile-time config.h. Installed when `enable = true`; turn either
    # off individually below.
    screen.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install GNU Screen and link suckless/screen/screenrc to ~/.screenrc.";
    };

    vi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install a classic vi and link suckless/vi/exrc to ~/.exrc.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nvi;
        defaultText = lib.literalExpression "pkgs.nvi";
        description = "The vi implementation to install (nvi by default; swap for pkgs.vim, etc.).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      cfg.tools
      ++ lib.optional cfg.screen.enable pkgs.screen
      ++ lib.optional cfg.vi.enable cfg.vi.package;

    # Runtime dotfiles for the two non-config.h tools.
    home.file.".screenrc" = lib.mkIf cfg.screen.enable { source = ./screen/screenrc; };
    home.file.".exrc" = lib.mkIf cfg.vi.enable { source = ./vi/exrc; };
  };
}
