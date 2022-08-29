{ config, pkgs, lib, ... }:

with lib;

let
  conf = config.shell_nix;

  nixpkgs_incl = if conf.nixpkgs != null then
    "-I nixpkgs=${escapeShellArg conf.nixpkgs}"
  else
    "";

in {
  options.shell_nix = {
    enabled = mkOption {
      type = types.bool;
      default = false;
      description = "Whether use 'shell.nix' in the workspace's tree.";
    };

    nixpkgs = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Pinned nixpkgs for evaluating the local shell.";
    };
  };

  config = mkIf conf.enabled {
    activation_command = ''
      if [[ -e ./shell.nix ]]
      then exec nix-shell ./shell.nix ${nixpkgs_incl} --run ${
        escapeShellArg config.command
      }
      else ${config.command}
      fi
    '';
  };
}
