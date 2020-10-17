{ pkgs, ... }:

# ./workspace example/example.nix "example"

let
  example_repo =
    pkgs.runCommandLocal "example_repo" {
      buildInputs = with pkgs; [ git ];
    } ''
      mkdir $out
      cd $out
      git init
      git config user.email "test@example.com"
      git config user.name "Example"
      echo "# Example" > README.md
      cat > shell.nix <<EOF
      { pkgs ? import <nixpkgs> {} }:
      let hello2 = pkgs.writeScriptBin "hello2" "echo hello2"; in
      pkgs.mkShell { buildInputs = [ hello2 ]; shellHook = "echo Hello 2"; }
      EOF
      git add README.md shell.nix
      git commit -am "Initial commit"
    '';

in

rec {
  example = {
    activation_script = '' hello '';
    buildInputs = with pkgs; [ hello ];
  };

  example2 = {
    imports = [ example ];
    vimrc = ''
      set modeline
    '';
    git.remotes = {
      origin = "${example_repo}";
    };
    git.gitignore = ''
      /ignored
    '';
    tools = [ ./example_tool.sh ];
    activation_script = ''
      echo hello world > ignored
    '';
  };
}
