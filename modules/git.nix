{ config, pkgs, lib, ... }:

with lib;

let
  conf = config.git;

  esc = escapeShellArg;

  mapAttrsToLines = f: attrs: concatStringsSep "\n" (mapAttrsToList f attrs);

  get_remote = role: remote:
    let r = getAttr remote conf.remotes;
    in if isAttrs r then getAttr role r else r;

  # If the 'main_remote' option correspond to a configured remote,
  # Use 'git clone' if possible, fallback to 'git init' if the
  # 'main_remote' option doesn't correspond to a configured remote.
  # If the main branch is set to be guessed, it might only be set in the
  # 'git clone' branch and won't be set in the fallback branch.
  init_repository = if hasAttr conf.main_remote conf.remotes then ''
    git clone --origin=${esc conf.main_remote} ${
      esc (get_remote "fetch" conf.main_remote)
    } .
    ${if conf.main_branch == null then ''
      # Set the 'MAIN' symbolic ref to the HEAD advertised by the remote.
      update_default_branch "$(git symbolic-ref --short HEAD)"
    '' else
      ""}
  '' else ''
    git init ${
      if conf.main_branch != null then
        "--initial-branch=${esc conf.main_branch}"
      else
        ""
    }
  '';

  # Remotes used to be set with the 'git remote' command instead of through the
  # included config file. This removes remotes that have been set this way.
  remove_legacy_remotes = mapAttrsToLines (name: url:
    ''
      remove_legacy_remote ${esc name} ${
        esc (if isAttrs url then url.fetch else url)
      } "fetch"'') conf.remotes;

  # If the 'main_branch' option is not set, make sure it is uptodate. Otherwise,
  # guess it.
  update_default_branch = if conf.main_branch == null then ''
    if ! [[ -e .git/MAIN ]]; then guess_default_branch; fi
  '' else
    "update_default_branch ${esc conf.main_branch}";

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

    # 'init_repository' might or might not fetch the main remote. In any case,
    # fetch again to be sure to have all the remotes and tags.
    init_script = ''
      . ${./git_update_states.sh}
      ${init_repository}
      git fetch --all --tags --update-head-ok --no-show-forced-updates --force
    '';

    activation_script = ''
      . ${./git_update_states.sh}
      ${remove_legacy_remotes}
      ${update_default_branch}
      git config set --local --all --value="^/nix/store/.*-workspace.git$" "include.path" ${
        builtins.toFile "workspace.git" local_config
      }
      remove_legacy_exclude_file
    '';
  };
}
