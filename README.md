# Nix-workspaces

Manage workspaces with Nix modules.

Example of definition:

```nix
{ pkgs ? import <nixpkgs> { } }:

let
  # Import this tool
  nix-workspaces = pkgs.callPackage (pkgs.fetchgit {
    url = "https://github.com/Julow/nix-workspaces";
    rev = "afceab5420e2e62c10088a34dbf6e03cddef1585";
    sha256 = "1102y4rfp72bgmcqyyqsympsxj8f7bfnksf1wyjv3b7vj6m32vlz";
  }) { };

  # Define base environment for the workspaces

  # A minimal dev environment.
  dev_env = {
    buildInputs = with pkgs; [ git fd ];
    vim.enable = true;
  };

  # A more complex base for ocaml projects. It's defined as a module and adds an option.
  ocaml_env = { lib, config, ... }: {
    options = {
      ocaml.ocamlformat = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ocamlformat_0_17_0;
      };
    };
    imports = [ dev_env ];
    config = {
      buildInputs = with pkgs; [
        opam ocaml
        ocamlPackages.ocp-indent config.ocaml.ocamlformat # Tools
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

  nix_env = {
    imports = [ dev_env ];
    buildInputs = with pkgs; [ nixfmt nix-prefetch-git ];
  };

in nix-workspaces {
  # Define workspaces

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

Some low-level options are defined in [workspaces.nix](./workspaces.nix), the others are in [modules/](./modules).

Build and install the workspaces:

```sh
nix-env -if workspaces.nix
```

This will fetch the dependencies of every workspaces and install a script called `workspaces`.

To open a workspace:

```sh
workspaces open ocamlformat
```

This is essentially calling `nix-shell`, see [workspaces](./workspaces).
The first time a workspace is opened, the git repository will be cloned into `$HOME/w/<workspace name>`.
