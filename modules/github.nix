{ pkgs, config, lib, ... }:

# Automatically set git remotes URL for Github repositories.
# To easily use this module, use a reusable workspace like:
#
#     gh = {
#       github.origin = "my username";
#     };
#
# It's also a good place to set 'github.ssh_prefix'.
# Then import in every workspaces that use Github:
#
#     imports = [ gh ];
#

with lib;

let
  conf = config.github;

  mkUrl = prefix: org: "${prefix}${org}/${config.name}";
  mkHttpUrl = mkUrl "https://github.com/";
  mkSshUrl = mkUrl conf.ssh_prefix;

  mkFetchUrl = if conf.private then
    assert assertMsg (conf.ssh_prefix != null)
      "'github.ssh_prefix' must be set when 'github.private' is set to 'true'.";
    mkSshUrl
  else
    mkHttpUrl;
  mkPushUrl = if conf.ssh_prefix != null then mkSshUrl else mkHttpUrl;

  mkPushPullUrl = org: {
    fetch = mkFetchUrl org;
    push = mkPushUrl org;
  };

in {
  options = with lib; {
    github.origin = mkOption {
      type = types.nullOr types.string;
      default = null;
      description = ''
        Set 'git.remotes.origin' to point to the Github repository
        '<this value>/<workspace name>'.
      '';
    };

    github.up = mkOption {
      type = types.nullOr types.string;
      default = null;
      description = ''
        Same as the 'origin' option but for a remote named 'up'.
      '';
    };

    github.extra_remotes = mkOption {
      type = types.listOf types.string;
      default = [ ];
      description = ''
        Extra remotes, named after the user hosting the repository. Useful for forks, for example.
      '';
    };

    github.ssh_prefix = mkOption {
      type = types.nullOr types.string;
      default = null;
      description = ''
        Prefix to use for SSH urls, which are used for 'push' url. If this is
        unset, only HTTPS urls are used.
      '';
    };

    github.private = mkOption {
      type = types.bool;
      default = false;
      description = "Use the SSH url for both push and fetch.";
    };
  };

  config = {
    git.remotes = {
      up = lib.mkIf (conf.up != null) (mkFetchUrl conf.up);
      origin = lib.mkIf (conf.origin != null) (mkPushPullUrl conf.origin);
    } // lib.genAttrs conf.extra_remotes mkPushPullUrl;
  };
}
