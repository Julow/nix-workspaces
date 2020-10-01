{ pkgs, config }:

with pkgs.lib;

let
  base_module = { config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = null;
        description = "Workspace name. Defaults to the attribute name used to define it.";
      };

      activation_script = mkOption {
        type = types.lines;
        default = "";
        description = "Script run when entering a workspace.";
      };

    };

    config = {};

  };

  make_workspace = name: configuration:
    let 
      default_name = { name = mkDefault name; };

      modules = evalModules {
        modules = [ base_module default_name configuration ];
      };
    in
    nameValuePair modules.config.name modules.config;

  make_activation_script = w:
    pkgs.writeScriptBin "activate" w.activation_script;

  make_workspaces = config:
    rec {
      workspaces = mapAttrs' make_workspace config;
      activation_scripts = mapAttrs (_: make_activation_script) workspaces;
    };

in

make_workspaces (import config { inherit pkgs; })
