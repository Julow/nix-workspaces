{ pkgs, config, lib, ... }:

with lib;

let
  # Wrap vim to source the local vimrc and to specify the per-workspace viminfo
  # This will be set to the 'command' option.
  wrapped_vim = { bin, vimrc }:
    let vimrc_file = builtins.toFile "${config.name}-vimrc" vimrc;
    in pkgs.writeShellScript "wrapped-vim" ''
      CACHE=$HOME/${config.cache_dir}
      mkdir -p "$CACHE"
      VIMINFO=$CACHE/viminfo
      SESSION=$CACHE/session.vim
      if ! [[ -e $SESSION ]]; then
        echo "let v:this_session = '$SESSION'" > $SESSION
      fi
      exec ${bin} -i "$VIMINFO" -S "${vimrc_file}" -S "$SESSION" "$@"
    '';

  # A script that calls 'vim' from the user's env.
  # This is the default value for the 'vim.bin' option.
  impure_vim = pkgs.writeShellScript "impure-vim" ''
    exec vim "$@"
  '';

in {
  options = {
    vim = {
      enable = mkEnableOption "vim";

      bin = mkOption {
        type = types.path;
        default = impure_vim;
        description =
          "Vim binary to use. The default is to lookup vim from the PATH.";
      };

      vimrc = mkOption {
        type = types.lines;
        default = "";
        description = "Local vimrc.";
      };

    };
  };

  config = mkIf (config.vim.enable != "") {
    command = "exec ${wrapped_vim { inherit (config.vim) bin vimrc; }}";
    vim.vimrc = ''
      " Remove some session options to make it work better with automatic sessions
      set sessionoptions=blank,help,tabpages,winsize,terminal

      autocmd VimLeave * execute "mksession!" v:this_session
    '';
  };
}
