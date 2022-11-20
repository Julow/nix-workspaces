{ pkgs }:

with pkgs.lib;

let
  eval_modules = modules:
    (evalModules {
      modules = [{ _module.args = { inherit pkgs; }; }] ++ modules;
    }).config;

  base_module = { config, ... }: {
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

      activation_command = mkOption {
        type = types.str;
        default = config.command;
        description =
          "Command run at the end of the activation script. The default is to run 'command'.";
      };
    };

    config = {
      activation_script = ''
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
        default = "${builtins.getEnv "HOME"}/w";
        description = "Base path under which workspaces are located.";
      };
    };
  };

  make_workspace = name: configuration:
    let default_name = { name = mkDefault name; };
    in eval_modules [
      base_module
      default_name # Base modules
      modules/git.nix
      modules/github.nix
      modules/shell_nix.nix
      modules/tools.nix
      modules/vim.nix
      modules/xdg.nix
      configuration # User configuration
    ];

  stdenv = pkgs.stdenvNoCC;

  # Generate the 'workspace-init' and 'workspace-activate' script for the
  # workspace.
  make_drv = w:
    stdenv.mkDerivation {
      name = strings.sanitizeDerivationName w.name;

      inherit (w) buildInputs;

      passAsFile = [ "init_script" "activation_script" ];
      init_script = ''
        #!${pkgs.runtimeShell}
        ${w.init_script}
      '';
      activation_script = ''
        mkdir -p "$HOME/${w.cache_dir}"
        ${w.activation_script}
        ${w.activation_command}
      '';

      # Similar to 'pkgs.writeShellScriptBin', inlined to avoid generating many
      # store paths.
      # Some build variables defined by stdenv are hardcoded into the
      # activation script to avoid needing 'nix-shell': 'PATH' and some
      # variables used by pkg-config, gcc and ld wrappers.
      buildPhase = ''
        mkdir -p $out/bin
        mv $init_scriptPath $out/bin/workspace-init
        chmod +x $out/bin/workspace-init
        ${stdenv.shell} -n $out/bin/workspace-init
        keep_var() { for v in "$@"; do echo "export $v=''\'''${!v}'"; done; }
        {
          echo "#!${pkgs.runtimeShell}"
          echo "PATH='$PATH':\"\$PATH\""
          for v in ''${!NIX_*}; do
            if [[ $v = *_FOR_TARGET || $v = *_TARGET_TARGET_* ]]; then
              keep_var $v
            fi
          done
          keep_var ''${!PKG_CONFIG_PATH_*}
          cat $activation_scriptPath
        } > $out/bin/workspace-activate
        chmod +x $out/bin/workspace-activate
        ${stdenv.shell} -n $out/bin/workspace-activate
      '';
      preferLocalBuild = true;
      allowSubstitutes = false;

      phases = [ "buildPhase" "fixupPhase" ];
    };

  # Hard code workspace derivation paths into the script
  make_entry_script = { prefix }:
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
      PREFIX=${escapeShellArg prefix}
      ${readFile ./workspaces.sh}
    '';

in config:
# Entry point. 'config' is a attributes set of workspaces. See 'base_module'
# above for the low-level options and './modules' for modules.
let
  workspaces_def = builtins.removeAttrs config [ "_default" ];
  workspaces = mapAttrsToList make_workspace workspaces_def;
  workspaces_drv = map make_drv workspaces;

  global_config =
    eval_modules [ global_configuration (config._default or { }) ];

  entry_script = make_entry_script global_config workspaces_drv;

in entry_script
