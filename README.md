# Nix-workspaces

Reproducible workspaces with Nix modules.

Workspaces encapsulate an environment and can be used to start a shell or an
editor. They are declared using the same module concept used in NixOS (it's a
generic [function](https://github.com/Julow/nix-workspaces/blob/f926f8288cc09fd146514028f519a6c29ea3ef6f/workspaces.nix#L69) available in `nixpkgs`),
see [examples](#Examples) below.

```sh
nix-env -if workspaces.nix
```

This makes sure that every workspaces are built and ready to be opened quickly.
It installs a single program, `workspaces` into the environment, that allows to
open them:

```sh
workspaces open <name>
```

The workspace description is very versatile, the [low-level options](./workspaces.nix)
`activation_script`, `buildInputs` and `command` are equivalent to a
`shell.nix`.

Other options are defined in [modules/](./modules). For example to define Git
remotes or to tweak your `.vimrc` for every workspace.

## Examples

This defines reusable base environment and a few workspaces.

```nix
{ pkgs ? import <nixpkgs> { } }:

let
  # Import this tool
  nix-workspaces = pkgs.callPackage (pkgs.fetchgit {
    url = "https://github.com/Julow/nix-workspaces";
    rev = "c4ab335b9be04d7622bc3fa61defa552884fcff5";
    sha256 = "1smh95p1blq2lq2l8v85lbqa5sc66j238m40y99j4xqfnigsspq6";
  }) { };

  # A reusable dev environment.
  dev_env = {
    buildInputs = with pkgs; [ git fd ];
    vim.enable = true;
  };

  # An other reusable environment built on top of the first one.
  nix_env = {
    imports = [ dev_env ];
    buildInputs = with pkgs; [ nixfmt nix-prefetch-git ];
  };

in nix-workspaces {
  # Define workspaces

  # Easy access to scratch workspaces.
  inherit dev_env nix_env;

  nix-workspaces = {
    imports = [ nix_env ];
    git.remotes.origin = "https://github.com/Julow/nix-workspaces";
  };

  nixpkgs = {
    imports = [ nix_env ];
    git.remotes.up = "https://github.com/NixOS/nixpkgs";
    vim.vimrc = ''
      set path+=pkgs/top-level
    '';
  };
}
```

An other example, defining a more complex `ocaml_env` environment.

```nix
{ pkgs ? import <nixpkgs> { } }:

let
  nix-workspaces = pkgs.callPackage (pkgs.fetchgit {
    url = "https://github.com/Julow/nix-workspaces";
    rev = "c4ab335b9be04d7622bc3fa61defa552884fcff5";
    sha256 = "1smh95p1blq2lq2l8v85lbqa5sc66j238m40y99j4xqfnigsspq6";
  }) { };

  dev_env = {
    buildInputs = with pkgs; [ git fd ];
    vim.enable = true;
  };

  ocaml_env = { lib, config, ... }: {
    options = {
      # Define an option that every workspaces can set to a different value
      ocaml.ocamlformat = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ocamlformat_0_17_0;
      };
    };
    imports = [ dev_env ];
    config = {
      buildInputs = with pkgs; [
        config.ocaml.ocamlformat
        opam ocaml ocamlPackages.ocp-indent # Tools
        m4 gmp libev pkgconfig # Dependencies of some important packages
      ];
      vim.vimrc = ''
        " This is project wide and not local to ft=ocaml
        set makeprg=dune\ build
        let g:runtestprg = "dune runtest --auto-promote"
        nnoremap <Leader>F :!dune build @fmt --auto-promote<return>
      '';
      activation_script = ''
        eval `opam env`
      '';
    };
  };

in nix-workspaces {
  inherit ocaml_env;

  ocamlformat = {
    imports = [ ocaml_env ];
    git.remotes = {
      origin = "https://github.com/Julow/ocamlformat";
      up = "https://github.com/ocaml-ppx/ocamlformat";
    };
    buildInputs = with pkgs; [ parallel ];
    vim.vimrc = ''
      autocmd FileType ocaml set formatprg=dune\ exec\ --\ ocamlformat\ --name\ %\ -
    '';
  };
}
```
