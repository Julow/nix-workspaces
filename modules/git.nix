{ config, pkgs, lib, ... }:

with lib;

let
  conf = config.git;

  esc = escapeShellArg;

  mapAttrsToLines = f: attrs: concatStringsSep "\n" (mapAttrsToList f attrs);

  update_states = ''
    . ${./git_update_states.sh}

    ${mapAttrsToLines (n: u: "update_remote ${esc n} ${esc u}") conf.remotes}

    update_default_branch ${esc conf.main_branch}
  '';
in

{
  options.git = {
    remotes = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Git remotes.";
    };

    main_branch = mkOption {
      type = types.str;
      default = "master";
      description = ''
        Defines the 'MAIN' symbolic ref.
        Also used to set the 'init.defaultBranch' config and for the initial
        checkout.
      '';
    };

    main_remote = mkOption {
      type = types.str;
      default = "origin";
    };

    gitignore = mkOption {
      type = types.lines;
      default = "";
      description = "Local gitignore rules.";
    };
  };

  config = mkIf (conf.remotes != {}) {
    buildInputs = with pkgs; [ git ];

    init_script = ''
      git init
      ${update_states}
      git fetch --all
      git checkout --track ${esc "${conf.main_remote}/${conf.main_branch}"}
    '';

    activation_script = ''
      ${update_states}

      ${if config.git.gitignore == "" then "" else ''
        # Gitignore
        ln -sf "${builtins.toFile "${config.name}-gitignore" conf.gitignore}" .git/info/exclude
      ''}
    '';

  };
}
