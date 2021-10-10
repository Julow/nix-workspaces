{ pkgs, config, lib, ... }:

with lib;

let
  # A script that calls 'vim' from the user's env.
  # This is the default value for the 'vim.bin' option.
  impure_vim = pkgs.writeShellScript "impure-vim" ''
    exec vim "$@"
  '';

  # Escaped for bash
  viminfo_path_esc = ''"$HOME"/${escapeShellArg config.cache_dir}/viminfo'';
  session_path_esc = ''"$HOME"/${escapeShellArg config.cache_dir}/session.vim'';

  vimrc_file = builtins.toFile "vimrc" config.vim.vimrc;

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
    command = ''
      exec ${config.vim.bin} -i ${viminfo_path_esc} -S ${vimrc_file} -S ${session_path_esc}
    '';

    activation_script = ''
      session_path=${session_path_esc}
      if ! [[ -e $session_path ]]; then
        echo "let v:this_session = \"$session_path\"" > "$session_path"
      fi

    '';

    vim.vimrc = ''
      " Remove some session options to make it work better with automatic sessions
      set sessionoptions=blank,help,tabpages,winsize,terminal

      autocmd VimLeave * execute "mksession!" v:this_session
    '';
  };
}
