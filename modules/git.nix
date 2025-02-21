{ config, pkgs, lib, ... }:

with lib;

let
  conf = config.git;

  esc = escapeShellArg;

  mapAttrsToLines = f: attrs: concatStringsSep "\n" (mapAttrsToList f attrs);

  get_remote = role: remote:
    let r = getAttr remote conf.remotes;
    in if isAttrs r then getAttr role r else r;

  gitignore_config = if config.git.gitignore == "" then
    ""
  else ''
    [core]
    excludesFile = ${builtins.toFile "gitignore" conf.gitignore}
  '';

  remotes_config = mapAttrsToLines (name: url: ''
    [remote "${name}"]
    ${if isAttrs url then ''
      url = ${url.fetch}
      pushurl = ${url.push}
    '' else ''
      url = ${url}
    ''}'') conf.remotes;

  local_config = ''
    ${gitignore_config}
    ${remotes_config}
  '';

in {
  options.git = with types; {
    remotes = mkOption {
      type = attrsOf (either str (submodule [{
        options = {
          fetch = mkOption { type = str; };
          push = mkOption { type = str; };
        };
      }]));
      default = { };
      description = ''
        Git remotes. When the workspace is activated, new remotes defined here
        are added to the Git repository automatically and changed URL are
        updated.
        Adding a remote is enough to activate this module. The repository is
        cloned on the first time the workspace is opened.
      '';
    };

    main_branch = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Defines the 'MAIN' symbolic ref.
        Also used to set the 'init.defaultBranch' config and for the initial
        checkout.
        By default, the default branch is taken from the remote repository
        during the initial checkout. This can only work if the 'main_remote'
        option is set to a configured remote.
        If it is not set at the time of activation, it is guessed.
      '';
    };

    main_remote = mkOption {
      type = str;
      default = "origin";
      description = "See the 'main_branch' option.";
    };

    gitignore = mkOption {
      type = lines;
      default = "";
      description = "Local gitignore rules.";
    };
  };

  config = mkIf (conf.remotes != { }) {
    buildInputs = with pkgs; [ git ];

    # If the 'main_remote' option correspond to a configured remote,
    # Use 'git clone' if possible, fallback to 'git init' if the
    # 'main_remote' option doesn't correspond to a configured remote.
    # If the main branch is set to be guessed, it might only be set in the
    # 'git clone' branch and won't be set in the fallback branch.
    init_script = ''
      ${if hasAttr conf.main_remote conf.remotes then ''
        git clone --origin=${esc conf.main_remote} ${
          esc (get_remote "fetch" conf.main_remote)
        } .
        ${if conf.main_branch == null then ''
          # Set the 'MAIN' symbolic ref to the HEAD advertised by the remote.
          MAIN=$(git symbolic-ref --short HEAD)
          git symbolic-ref MAIN "refs/heads/$MAIN"
        '' else
          ""}
      '' else ''
        git init ${
          if conf.main_branch != null then
            "--initial-branch=${esc conf.main_branch}"
          else
            ""
        }
      ''}
      git fetch --all --tags --update-head-ok --no-show-forced-updates --force
    '';

    activation_script = ''
      ${
      # Remove remotes and ignore rules previously set using 'git remote' and
      # '.git/info/exclude' as they take precedence over the new method using an
      # included config file.
      ""}
      # Migrate workspaces using an old format
      if ! git config get --local --value="^/nix/store/.*-workspace.git$" include.path &>/dev/null; then
        # Remove all remotes
        while read name; do
          git remote remove "$name"
        done < <(git remote)
        rm -f .git/info/exclude # Now set through config
      fi

      git config set --local --all --value="^/nix/store/.*-workspace.git$" "include.path" ${
        builtins.toFile "workspace.git" local_config
      }

      ${
      # If the 'main_branch' option is set, the 'MAIN' symbolic ref is updated to
      # point to the specified branch.
      # If it is not set, the branch to use is guessed from a list of probable main
      # branches.
      if conf.main_branch == null then ''
        guess_default_branch ()
        {
          local default=$(git config init.defaultBranch)
          for guess in "$default" main master trunk; do
            if [[ -e .git/refs/heads/$guess ]]; then
              git symbolic-ref MAIN "refs/heads/$guess"
              return
            fi
          done
        }

        if ! [[ -e .git/MAIN ]]; then guess_default_branch; fi
      '' else ''
        echo ${esc "refs/heads/${conf.main_branch}"} > .git/MAIN
      ''}
    '';

  };
}
