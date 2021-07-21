{ pkgs ? import <nixpkgs> {} }:

import ./workspaces.nix { inherit pkgs; }
