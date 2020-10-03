{ pkgs, config, lib, ... }:

with lib;

{
  options = {
    tools = mkOption {
      type = types.listOf types.path;
      default = [];
      description = "Scripts that will added to the PATH.";
    };

  };

  config = mkIf (config.tools != []) {
    buildInputs =
      let
        tools = map (p: { name = "bin/${baseNameOf p}"; path = p; }) config.tools;
        drv = (pkgs.linkFarm "tools-${config.name}" tools);
      in
      [ drv ];

  };
}
