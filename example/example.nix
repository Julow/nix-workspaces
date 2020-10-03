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
      git add README.md
      git commit -am "Initial commit"
      echo hello world > ignored
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
  };

}
