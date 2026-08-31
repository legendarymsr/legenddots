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

    # Not suckless, but shipped alongside for the minimalist collection, configured
    # via runtime dotfiles rather than a compile-time config.h. screen is installed
    # and configured; vim is config-only (we link a minimal ~/.vimrc, install no
    # editor). Both come along when `enable = true`; turn either off individually below.
    screen.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install GNU Screen and link suckless/screen/screenrc to ~/.screenrc.";
    };

    # vim is config-only: we link a very minimal ~/.vimrc but don't install vim
    # (it's in every distro's main repo; add it yourself).
    vim.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Link suckless/vim/vimrc to ~/.vimrc (config only — vim not installed).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      cfg.tools
      ++ lib.optional cfg.screen.enable pkgs.screen;

    # Runtime dotfiles for the two non-config.h tools.
    home.file.".screenrc" = lib.mkIf cfg.screen.enable { source = ./screen/screenrc; };
    home.file.".vimrc" = lib.mkIf cfg.vim.enable { source = ./vim/vimrc; };
  };
}
