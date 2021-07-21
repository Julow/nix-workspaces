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
        mkdir -p "$HOME/${config.cache_dir}"
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
          base_module
          default_name # Base modules
          modules/git.nix
          modules/vim.nix
          modules/tools.nix
          configuration # User configuration
        ];
        args = { inherit pkgs; };
      };
    in modules.config;

  make_activation_script = w:
    let
      do_activate = if w.local_shell then ''
        if [[ -e ./shell.nix ]];
        then nix-shell ./shell.nix --run '${w.command}'
        else ${w.command}; fi
      '' else
        w.command;
    in ''
      ${w.activation_script}
      ${do_activate}
    '';

  make_drv = w:
    let
      init = pkgs.writeShellScriptBin "workspace-init" w.init_script;
      activate = pkgs.writeShellScriptBin "workspace-activate"
        (make_activation_script w);
      # Turn a list of dependencies into a single derivation with propagatedBuildInputs
    in pkgs.stdenvNoCC.mkDerivation {
      name = strings.sanitizeDerivationName w.name;
      propagatedBuildInputs = w.buildInputs ++ [ init activate ];
      # fixupPhase does the "propagatedBuildInputs" thing
      phases = [ "installPhase" "fixupPhase" ];
      # installPhase to avoid the "No such file or directory" errors
      installPhase = "mkdir -p $out";
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
