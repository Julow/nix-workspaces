{ config, pkgs, lib, ... }:

with lib;

let
  conf = config.git;

  sync_remotes = ''
    # Sync remotes
    ${pkgs.bash}/bin/bash ${./sync_git_remotes.sh} <<"EOF"
    ${concatStringsSep "\n" (mapAttrsToList (n: u: "${n} ${u}") conf.remotes)}
    EOF
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
      ${sync_remotes}
      git fetch --all
      git checkout --track "${conf.main_remote}/${conf.main_branch}"
    '';

    activation_script = ''
      ${sync_remotes}

      ${if config.git.gitignore == "" then "" else ''
        # Gitignore
        ln -sf "${builtins.toFile "${config.name}-gitignore" conf.gitignore}" .git/info/exclude
      ''}
    '';

  };
}
