{ pkgs, config }:

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
    in nameValuePair modules.config.name modules.config;

  make_activation_script = w:
    pkgs.writeShellScriptBin "workspace-activate" ''
      ${w.activation_script}

      if [[ -e ./shell.nix ]]; then
        echo "Using shell.nix"
        nix-shell ./shell.nix --run '${w.command}'
      else
        ${w.command}
      fi
    '';

  make_workspaces = config: rec {
    workspaces = mapAttrs' make_workspace config;
    workspace_names = mapAttrsToList (_: w: w.name) workspaces;
    by_name = { wname }:
      assert (builtins.hasAttr wname workspaces
        || throw "Workspace ${wname} not found");
      let
        w = builtins.getAttr wname workspaces;
        init = pkgs.writeShellScriptBin "workspace-init" w.init_script;
        activate = make_activation_script w;
      in w.buildInputs ++ [ init activate ];
  };

in make_workspaces (import config { inherit pkgs; })
