{ config, pkgs, lib, ... }:

with lib;

let conf = config.git; in

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

  };

  config = mkIf (conf.remotes != {}) {
    buildInputs = with pkgs; [ git ];

    activation_script = ''
      # Init if not already
      did_init=0
      if ! [[ -e .git ]]; then git init; did_init=1; fi

      # Sync remotes
      ${pkgs.bash}/bin/bash ${./sync_git_remotes.sh} <<"EOF"
      ${concatStringsSep "\n" (mapAttrsToList (n: u: "${n} ${u}") conf.remotes)}
      EOF

      # If init, fetch remotes
      if [[ $did_init -eq 1 ]]; then
        git fetch --all
        git checkout --track "${conf.main_remote}/${conf.main_branch}"
      fi
    '';

  };
}
