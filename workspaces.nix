{ pkgs }:

with pkgs.lib;

let
  eval_modules = modules:
    (evalModules {
      modules = [{ _module.args = { inherit pkgs; }; }] ++ modules;
    }).config;

  base_module = { config, ... }: {
    imports = [
      modules/git.nix
      modules/github.nix
      modules/shell_nix.nix
      modules/tools.nix
      modules/vim.nix
      modules/xdg.nix
    ];

    options = {
      name = mkOption {
        type = types.str;
        default = null;
        description =
          "Workspace name. Defaults to the attribute name used to define it.";
      };

      init_script = mkOption {
        type = types.lines;
        default = "";
        description = "Run when the workspace is activated for the first time.";
      };

      activation_script = mkOption {
        type = types.lines;
        default = "";
        description = "Script run when entering a workspace.";
      };

      env_script = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell script that sets environment variables. Included in
          'activation_script' but can be used to enter an environment without
          running the full activation script and the command.
        '';
      };

      command = mkOption {
        type = types.str;
        default = "${pkgs.bashInteractive}/bin/bash";
        description = "Command to run after activation.";
      };

      buildInputs = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Workspace dependencies.";
      };

      cache_dir = mkOption {
        type = types.str;
        default = ".cache/workspaces/${config.name}";
        description = ''
          Directory for per-workspace cache, relative to the home directory.
          Used to store history files and other unimportant things.
        '';
      };

      nix_builder_vars = mkOption {
        type = types.listOf types.str;
        default = [
          "PKG_CONFIG_PATH_*" "NIX_*_FOR_TARGET" "NIX_*_TARGET_TARGET_*"
        ];
        description = ''
          Variables from the builder's environment to persist in the
          workspace. The builder's environment is impacted by 'buildInputs'.
          Asterisks can be used to match many variables.
        '';
      };

      nix_builder_vars_path = mkOption {
        type = types.listOf types.str;
        default = [ "PATH" "PYTHONPATH" ];
        description = ''
          Like 'nix_builder_vars' but for variables containing paths separated
          by ':'. The new paths are concatenated at the front of the content.
          Asterisks are not supported.
        '';
      };

      activation_command = mkOption {
        type = types.str;
        default = config.command;
        description =
          "Command run at the end of the activation script. The default is to run 'command'.";
      };
    };

    config = {
      activation_script = ''
        mkdir -p "$HOME/${config.cache_dir}"
        export WORKSPACE=${config.name}
        export HISTFILE=$HOME/${config.cache_dir}/bash_history
      '';
    };

  };

  # Options for the '_default' attribute.
  global_configuration = { config, ... }: {
    options = {
      prefix = mkOption {
        type = types.str;
        default = "$HOME/w";
        description = ''
          Base path under which workspaces are located. Can contain bash
          substitutions, which will be evaluated when the entry script is
          called.
        '';
      };

      defaults = mkOption {
        type = with types; oneOf [ attrs (functionTo attrs) ];
        # type = types.deferredModule {}; # Too recent
        default = { };
        description = ''
          Configuration added to every workspaces. Useful to configure
          'activation_command' or to add basic tools to 'buildInputs'.
        '';
      };
    };
  };

  make_workspace = { defaults, ... }: name: configuration:
    let default_name = { name = mkDefault name; };
    in eval_modules [
      base_module
      default_name # Base modules
      defaults # From global configuration
      configuration # User configuration
    ];

  stdenv = pkgs.stdenvNoCC;

  # Snippet of bash script that persist env variables
  persist_builder_vars =
    export: var:
    let
      # The ${!...} syntax only supports one asterisk, at the end. The rest of
      # the pattern is checked using [[ = ]].
      vs = strings.splitString "*" var;
      v0 = elemAt vs 0;
    in ''
      for v in ''${!${v0}*}; do
        if [[ $v = ${var} ]]; then
          echo "export $v=${export}"
        fi
      done
    '';

  # Generate the 'workspace-init', 'workspace-activate' and 'workspace-env'
  # script for the workspace.
  make_drv = w:
    stdenv.mkDerivation {
      name = strings.sanitizeDerivationName w.name;

      inherit (w)
      buildInputs init_script activation_script env_script activation_command;

      passAsFile = [
        "init_script" "activation_script" "env_script" "activation_command"
      ];

      # Similar to 'pkgs.writeShellScriptBin', inlined to avoid generating many
      # store paths.
      # Some build variables defined by stdenv are hardcoded into the
      # activation script to avoid needing 'nix-shell': 'PATH' and some
      # variables used by pkg-config, gcc and ld wrappers.
      buildPhase = ''
        mkdir -p $out/bin
        {
          echo "#!${pkgs.runtimeShell}"
          cat $init_scriptPath
        } > $out/bin/workspace-init
        {
          ${concatMapStrings
            (persist_builder_vars "'\${!v}'")
            w.nix_builder_vars}
          ${concatMapStrings
            (persist_builder_vars "'\${!v}':\"\\$$v\"")
            w.nix_builder_vars_path}
          cat $env_scriptPath
        } > $out/bin/workspace-env
        {
          echo "#!${pkgs.runtimeShell}"
          cat $out/bin/workspace-env $activation_scriptPath $activation_commandPath
        } > $out/bin/workspace-activate
        chmod +x $out/bin/workspace-{init,activate}
        ${stdenv.shell} -n $out/bin/workspace-*
      '';
      preferLocalBuild = true;
      allowSubstitutes = false;

      phases = [ "buildPhase" "fixupPhase" ];
    };

  # Hard code workspace derivation paths into the script
  make_entry_script = { prefix, ... }:
    workspaces:
    pkgs.writeShellScriptBin "workspaces" ''
      declare -A workspaces
      workspaces=(
        ${
          concatMapStrings (drv: ''
            ["${drv.name}"]="${drv}"
          '') workspaces
        }
      )
      # Sorted list of workspaces for use in the 'list' and 'status' commands.
      workspaces_names=(
        ${concatMapStringsSep " " (drv: ''"${drv.name}"'') workspaces}
      )
      PREFIX=${prefix}
      ${readFile ./workspaces.sh}
    '';

in config:
# Entry point. 'config' is a attributes set of workspaces. See 'base_module'
# above for the low-level options and './modules' for modules.
let
  global_config =
    eval_modules [ global_configuration (config._default or { }) ];

  workspaces_def = builtins.removeAttrs config [ "_default" ];
  workspaces =
    mapAttrsToList (make_workspace global_config) workspaces_def;
  workspaces_drv = map make_drv workspaces;

  entry_script = make_entry_script global_config workspaces_drv;

in entry_script
