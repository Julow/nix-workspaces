{ config, pkgs, lib, ... }:

with lib;

let
  conf = config.shell_nix;

  nixpkgs_incl = if conf.nixpkgs != null then
    "-I nixpkgs=${escapeShellArg conf.nixpkgs}"
  else
    "";

  # The shell's dependencies are rooted and the derivation is cached to make
  # opening shells persistent. Opening a shell is faster and doesn't require
  # internet access until the 'shell.nix' file changes.
  # https://github.com/NixOS/nix/issues/2208
  cached_shell_roots_sh = ''"$HOME/${config.cache_dir}/shell_roots"'';
  cached_shell_drv_sh = ''"$HOME/${config.cache_dir}/shell.drv"'';
  cached_shell_nix_sh = ''"$HOME/${config.cache_dir}/shell.nix"'';

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
      then
        # Evaluate and build only when 'shell.nix' changes
        set -ex
        if ! diff ./shell.nix ${cached_shell_nix_sh} &>/dev/null; then
          mkdir -p ${cached_shell_roots_sh}
          nix-instantiate shell.nix ${nixpkgs_incl} --indirect --add-root ${cached_shell_drv_sh}
          nix-store --indirect --add-root ${cached_shell_roots_sh}/result --realise $(nix-store --query --references ${cached_shell_drv_sh})
          cat ./shell.nix > ${cached_shell_nix_sh}
        fi
        exec nix-shell ${cached_shell_drv_sh} --run ${
          escapeShellArg config.command
        }
      else ${config.command}
      fi
    '';
  };
}
