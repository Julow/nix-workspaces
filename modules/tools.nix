{ pkgs, config, lib, ... }:

with lib;

{
  options = {
    tools = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Scripts that will added to the PATH.";
    };

  };

  config = mkIf (config.tools != [ ]) {
    buildInputs = let
      # Sorted by input path to remove duplicates due to diamond shaped
      # imports.
      tools = attrValues (listToAttrs (map (p: {
        name = toString p;
        value = {
          name = "bin/${baseNameOf p}";
          path = builtins.path { path = p; };
        };
      }) config.tools));
      drv = (pkgs.linkFarm "tools" tools);
    in [ drv ];

  };
}
