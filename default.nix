{ pkgs ? import <nixpkgs> {} }:

let
  runtimeDeps = with pkgs; pkgs.lib.makeBinPath [ nix jq bash ];
in

pkgs.runCommandLocal "nix-workspaces" {
  src = ./.;
} ''
  mkdir -p "$out" "$out/bin" "$out/nix"
  cp -r "$src/workspaces.nix" "$src/modules" "$out/nix"
  sed "2 i PATH=${runtimeDeps}:\$PATH; NIX_SRC=$out/nix" "$src/workspaces" > $out/bin/workspaces
  chmod +x "$out/bin/workspaces"
''
