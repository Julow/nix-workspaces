{ pkgs, ... }:

# ./workspace example/example.nix "example"

{
  example = {
    activation_script = '' echo hello '';
  };
  example2 = {
    activation_script = '' echo world '';
  };
}
