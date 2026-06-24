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

  # Module implementing sessions
  session_module = {
    options.vim.session = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Save the session automatically when Vim exists (eg. with :qa) and
        restore it when the workspace is opened again.
      '';
    };

    config = mkIf config.vim.session {
      vim.cli_args_unescaped = [
        "-S"
        session_path_esc
      ];

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
  };

in
{
  imports = [ session_module ];

  options = {
    vim = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable vim. The 'command' is set to call Vim, with a custom .vimrc
          and a session file.
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

      cli_args_unescaped = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Like 'vim.cli_args' but the argument are not escaped and can ues Bash substitutions.";
      };
    };
  };

  config = mkIf config.vim.enable {
    vim.cli_args = [
      "-S"
      vimrc_file
    ];

    vim.cli_args_unescaped = [
      "-i"
      viminfo_path_esc
      (escapeShellArgs config.vim.cli_args)
    ];

    command = ''
      exec ${config.vim.bin} ${concatStringsSep " " config.vim.cli_args_unescaped}
    '';
  };
}
