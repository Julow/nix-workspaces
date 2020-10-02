{ pkgs, ... }:

# ./workspace example/example.nix "example"

rec {
  example = {
    activation_script = '' hello '';
    buildInputs = with pkgs; [ hello ];
  };
  example2 = {
    imports = [ example ];
    activation_script = '' echo world '';
    vimrc = ''
      set modeline
    '';
  };
}
