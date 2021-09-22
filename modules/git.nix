{ config, pkgs, lib, ... }:

with lib;

let
  conf = config.git;

  # Sync remotes
  sync_remotes = ''
    ${pkgs.bash}/bin/bash ${./sync_git_remotes.sh} <<"EOF"
    ${concatStringsSep "\n" (mapAttrsToList (n: u: "${n} ${u}") conf.remotes)}
    EOF
  '';

  # Sync the MAIN symbolic ref
  # Also update the 'init.defaultBranch' config in case it's used by some scripts
  sync_default_branch = ''
    main=MAIN
    def_branch=${escapeShellArg conf.main_branch}
    main_ref=refs/heads/$def_branch
    if [[ `git symbolic-ref "$main" 2>/dev/null` != $main_ref ]]; then
      git symbolic-ref "$main" "$main_ref"
      git config init.defaultBranch "$def_branch"
    fi
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
      ${sync_default_branch}
      ${sync_remotes}
      git fetch --all
      git checkout --track ${escapeShellArg "${conf.main_remote}/${conf.main_branch}"}
    '';

    activation_script = ''
      ${sync_default_branch}
      ${sync_remotes}

      ${if config.git.gitignore == "" then "" else ''
        # Gitignore
        ln -sf "${builtins.toFile "${config.name}-gitignore" conf.gitignore}" .git/info/exclude
      ''}
    '';

  };
}
