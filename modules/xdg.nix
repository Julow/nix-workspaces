{ pkgs, config, lib, ... }:

with lib;

let
  conf = config.xdg.config;

  # All the parent directories of 'conf.files'
  files_prefixes =
    unique ([ "." ] ++ mapAttrsToList (rel: _: dirOf rel) conf.files);
in {
  options = {
    xdg.config = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Set '$XDG_CONFIG_HOME' to a path unique to each workspace.
        '';
      };

      files = mkOption {
        type = lib.types.attrsOf types.path;
        default = { };
        description = ''
          Static files to link into the xdg config directory.
          Attribute name is relative path into the xdg/config directory.
        '';
      };
    };
  };

  config = mkIf conf.enable {
    activation_script = ''
      export XDG_CONFIG_HOME=$HOME/${escapeShellArg config.cache_dir}/xdg/config

      mkdir -p ${
        concatStringsSep " "
        (map (p: ''"$XDG_CONFIG_HOME"/${escapeShellArg p}'') files_prefixes)
      }

      ${concatStringsSep "\n" (mapAttrsToList (rel: dst: ''
        ln -sf ${escapeShellArg dst} "$XDG_CONFIG_HOME"/${escapeShellArg rel}
      '') conf.files)}
    '';
  };
}
