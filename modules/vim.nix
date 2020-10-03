{ pkgs, config, lib, ... }:

with lib;

{
  options = {
    vimrc = mkOption {
      type = types.lines;
      default = "";
      description = "Local vimrc. Will be symlinked at the root of the workspace.";
    };

  };

  config = mkIf (config.vimrc != "") {
    activation_script = ''
      ln -sf "${builtins.toFile "${config.name}-vimrc" config.vimrc}" .vimrc
    '';
    git.gitignore = ''
      /.vimrc
    '';

  };
}
