# Nix-workspaces

Manage workspaces with Nix.

Example:

```nix
{ pkgs, ... }:

let
  ocaml_env = {
    buildInputs = with pkgs; [ gmp glibc ];
    activation_script = ''
      eval `opam env`
    '';
  };
in

{
  nix-workspaces = {
    git.remotes.origin = "https://github.com/Julow/nix-workspaces";
    buildInputs = with pkgs; [ jq ];
  };

  ocamlformat = {
    imports = [ ocaml_env ];
    git.remotes = {
      origin = "https://github.com/Julow/ocamlformat";
      up = "https://github.com/ocaml-ppx/ocamlformat";
    };
    buildInputs = with pkgs; [ parallel ];
    vimrc = ''
      autocmd FileType ocaml set formatprg=dune\ exec\ --\ ocamlformat\ --name\ %\ -
    '';
  };
}
```

```sh
workspaces open -f example.nix nix-workspaces
```
