{ pkgs, config, lib, ... }:

with lib;

let
  # Wrap vim to source the local vimrc
  make_wrapped_vim = vimrc:
    let vimrc_file = builtins.toFile "${config.name}-vimrc" config.vimrc; in
    # Expect vim to be in the user's environment on purpose,
    # to avoid shadowing an existing override/wrap
    pkgs.runCommand "${config.name}-vim" {} ''
      mkdir -p "$out/bin"
      cat <<EOF > "$out/bin/vim"
      #!/usr/bin/env bash
      this="$out"
      PATH=\''${PATH//\$this/} # Remove this package from the PATH
      exec vim -c "source ${vimrc_file}" "\$@"
      EOF
      chmod +x "$out/bin/vim"
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
    buildInputs = [ (make_wrapped_vim config.vimrc) ];

  };
}
