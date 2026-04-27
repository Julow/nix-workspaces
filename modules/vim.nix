{
  pkgs,
  config,
  lib,
  ...
}:

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

  cli_args_escaped = lib.concatStringsSep " " [
    "-i"
    viminfo_path_esc
    "-S"
    session_path_esc
    (lib.escapeShellArgs config.vim.cli_args)
  ];

in
{
  options = {
    vim = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable vim. The 'command' is set to call Vim, with a custom .vimrc
          and a session file.
          The session file is saved automatically when Vim exists. (eg. with :qa)
        '';
      };

      bin = mkOption {
        type = types.path;
        default = impure_vim;
        description = "Vim binary to use. The default is to lookup vim from the PATH.";
      };

      vimrc = mkOption {
        type = types.lines;
        default = "";
        description = "Local vimrc.";
      };

      cli_args = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Command-line argument passed when starting Vim.";
      };
    };
  };

  config = mkIf (config.vim.enable != "") {
    vim.cli_args = [
      "-S"
      vimrc_file
    ];

    command = ''
      exec ${config.vim.bin} ${cli_args_escaped}
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
