{ pkgs, config, lib, ... }:

with lib;

let
  # Wrap vim to source the local vimrc and to specify the per-workspace viminfo
  wrapped_vim =
    let vimrc_file = builtins.toFile "${config.name}-vimrc" config.vimrc; in
    # Expect vim to be in the user's environment on purpose,
    # to avoid shadowing an existing override/wrap
    pkgs.writeShellScriptBin "vim" ''
      this=''${0%/vim}
      p=:$PATH:
      p=''${p//:$this:/:}
      p=''${p%:}
      export PATH=''${p#:}
      exec vim -c "source ${vimrc_file}" -i "$HOME/${config.cache_dir}/viminfo" "$@"
    '';
in

{
  options = {
    vimrc = mkOption {
      type = types.lines;
      default = "";
      description = "Local vimrc.";
    };

  };

  config = mkIf (config.vimrc != "") {
    buildInputs = [ wrapped_vim ];

  };
}
