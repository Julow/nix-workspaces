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

      command = mkOption {
        type = types.str;
        default = "${pkgs.bashInteractive}/bin/bash";
        description = "Command to run after activation.";
      };

      buildInputs = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "Workspace dependencies.";
      };

    };

    config = {};

  };

  make_workspace = name: configuration:
    let 
      default_name = { name = mkDefault name; };

      modules = evalModules {
        modules = [
          base_module default_name # Base modules
          modules/git.nix
          modules/vim.nix
          configuration # User configuration
        ];
        args = {
          inherit pkgs;
        };
      };
    in
    nameValuePair modules.config.name modules.config;

  make_activation_script = w:
    let
      activate = pkgs.writeShellScriptBin "activate" ''
        set -e
        ${w.activation_script}
        exec ${w.command}
      '';
    in
    pkgs.mkShell {
      buildInputs = [ activate ] ++ w.buildInputs;
    };

  make_workspaces = config:
    rec {
      workspaces = mapAttrs' make_workspace config;
      activation_scripts = mapAttrs (_: w: (make_activation_script w).drvPath) workspaces;
    };

in

make_workspaces (import config { inherit pkgs; })
