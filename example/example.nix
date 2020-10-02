{ pkgs, ... }:

# ./workspace example/example.nix "example"

{
  example = {
    activation_script = '' hello '';
    buildInputs = with pkgs; [ hello ];
  };
  example2 = {
    activation_script = '' echo world '';
  };
}
