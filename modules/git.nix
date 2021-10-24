{ config, pkgs, lib, ... }:

with lib;

let
  conf = config.git;

  esc = escapeShellArg;

  mapAttrsToLines = f: attrs: concatStringsSep "\n" (mapAttrsToList f attrs);

  origin_url = getAttr conf.main_remote conf.remotes;

  # If the 'main_remote' option correspond to a configured remote,
  # Use 'git clone' if possible, fallback to 'git init' if the
  # 'main_remote' option doesn't correspond to a configured remote.
  # If the main branch is set to be guessed, it might only be set in the
  # 'git clone' branch and won't be set in the fallback branch.
  init_repository = if hasAttr conf.main_remote conf.remotes then ''
    git clone --origin=${esc conf.main_remote} ${esc origin_url} .
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

  update_remotes = ''
    ${mapAttrsToLines (n: u: "update_remote ${esc n} ${esc u}") conf.remotes}
  '';

  # If the 'main_branch' option is set, make sure it is uptodate
  update_default_branch = if conf.main_branch == null then
    ""
  else
    "update_default_branch ${esc conf.main_branch}";

  update_gitignore = if config.git.gitignore == "" then
    ""
  else ''
    ln -sf "${builtins.toFile "gitignore" conf.gitignore}" .git/info/exclude
  '';

in {
  options.git = {
    remotes = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Git remotes.";
    };

    main_branch = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Defines the 'MAIN' symbolic ref.
        Also used to set the 'init.defaultBranch' config and for the initial
        checkout.
        By default, the default branch is taken from the remote repository
        during the initial checkout. This can only work if the 'main_remote'
        option is set to a configured remote.
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

  config = mkIf (conf.remotes != { }) {
    buildInputs = with pkgs; [ git ];

    # 'init_repository' might or might not fetch the main remote. In any case,
    # fetch again to be sure to have all the remotes and tags.
    init_script = ''
      . ${./git_update_states.sh}
      ${init_repository}
      ${update_remotes}
      git fetch --all --tags --update-head-ok --no-show-forced-updates --force
    '';

    activation_script = ''
      . ${./git_update_states.sh}
      ${update_remotes}
      ${update_default_branch}
      ${update_gitignore}
    '';
  };
}
