{ pkgs }:

with pkgs.lib;

let
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
        description =
          "Directory for per-workspace cache, relative to the home directory. Used to store history files and other unimportant things.";
      };

      local_shell = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to build and use a local 'shell.nix'.";
      };

    };

    config = {
      activation_script = ''
        export WORKSPACE=${config.name}
        export HISTFILE=$HOME/${config.cache_dir}/bash_history
      '';
    };

  };

  make_workspace = name: configuration:
    let
      default_name = { name = mkDefault name; };

      modules = evalModules {
        modules = [
          { _module.args = { inherit pkgs; }; }
          base_module
          default_name # Base modules
          modules/git.nix
          modules/vim.nix
          modules/tools.nix
          modules/xdg.nix
          configuration # User configuration
        ];
      };
    in modules.config;

  make_activation_script = w:
    let
      do_activate = if w.local_shell then ''
        if [[ -e ./shell.nix ]];
        then
          exec nix-shell ./shell.nix --run ${escapeShellArg w.command}
        else
          ${w.command}
        fi
      '' else
        w.command;

      # Make sure the cache directory is available to the activation script
      pre_activation_script = ''
        mkdir -p "$HOME/${w.cache_dir}"
      '';
    in ''
      #!${pkgs.runtimeShell}
      ${pre_activation_script}
      ${w.activation_script}
      ${do_activate}
    '';

  # The derivation for a workspace
  # Contains the scripts 'workspace-init' and 'workspace-activate' and has the
  # dependencies as 'propagatedBuildInputs'
  make_drv = w:
    pkgs.stdenvNoCC.mkDerivation {
      name = strings.sanitizeDerivationName w.name;
      propagatedBuildInputs = w.buildInputs;

      passAsFile = [ "init_script" "activation_script" ];
      init_script = ''
        #!${pkgs.runtimeShell}
        ${w.init_script}
      '';
      activation_script = make_activation_script w;

      # The same build and check phases as 'pkgs.writeShellScriptBin' inlined
      # here to avoid generating many store paths.
      buildPhase = ''
        mkdir -p $out/bin
        mv $init_scriptPath $out/bin/workspace-init
        chmod +x $out/bin/workspace-init
        ${pkgs.stdenv.shell} -n $out/bin/workspace-init
        mv $activation_scriptPath $out/bin/workspace-activate
        chmod +x $out/bin/workspace-activate
        ${pkgs.stdenv.shell} -n $out/bin/workspace-activate
      '';
      preferLocalBuild = true;
      allowSubstitutes = false;

      # fixupPhase does the "propagatedBuildInputs" thing
      phases = [ "buildPhase" "fixupPhase" ];
    };

  # Hard code workspace derivation paths into the script
  make_entry_script = workspaces:
    pkgs.writeShellScriptBin "workspaces" ''
      declare -A workspaces
      workspaces=(
        ${
          concatMapStrings (drv: ''
            ["${drv.name}"]="${drv}"
          '') workspaces
        }
      )
      ${readFile ./workspaces}
    '';

in config:
make_entry_script (map make_drv (mapAttrsToList make_workspace config))
