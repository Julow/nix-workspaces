{
  config,
  pkgs,
  lib,
  ...
}:

# Build a Docker image with the workspace's environment.
# The image is very small and use the host's Nix store.
#
# Run it with 'cont' or 'cont command args...'.
# The current directory is automatically mounted r/w into the container.

with lib;

let
  conf = config.docker;

  image = pkgs.dockerTools.streamLayeredImage {
    name = "cont";
    tag = "latest";
    config.Entrypoint = [ entrypoint ];
    config.Env = [ "HOME=${conf.home_dir}" ];
    config.WorkingDir = "/w";
    # Create a world readable home directory to allow using 'docker run -u'.
    fakeRootCommands = ''
      mkdir -p ".${conf.home_dir}" tmp
      chmod 1777 ".${conf.home_dir}"
      chmod 1777 tmp
    '';
  };

  # Querying the workspace env at runtime to avoid
  # constructing the image for every workspaces,
  # which slows down significantly the build.
  entrypoint = pkgs.writeShellScript "entrypoint" ''
    workspace=$1; shift
    source "$workspace/bin/workspace-env"
    exec "$@"
  '';

  esc = lib.escapeShellArg;

  mount_args = flag: dirs: lib.concatMapStringsSep " " (dir: "-v ${esc dir}:${esc dir}:${flag}") dirs;

  # Use -u to make the files created in the container have the right ownership
  # on the host.
  cont = pkgs.writeShellScriptBin "cont" ''
    set -ex
    # Make sure all the mounted directories are created, otherwise docker
    # will create them with owner root.
    mkdir -p ${lib.concatMapStringsSep " " esc conf.mounts}
    ${image} | docker image load
    if [[ $# -eq 0 ]]; then set bash; fi
    docker run --rm -ti -v "$PWD:/w" \
      -u "$(id -u):$(id -g)" \
      -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
      ${mount_args "ro" conf.mounts} \
      ${mount_args "rw" conf.mounts_read_write} \
      "cont" "$(workspaces drv "$WORKSPACE")" "$@"
  '';

in
{
  options.docker = with types; {
    enable = mkEnableOption "docker";

    home_dir = mkOption {
      type = str;
      description = ''
        Home directory within the container. Should match the host path if
        directories from the home directory are mounted.
      '';
    };

    mounts = mkOption {
      type = listOf str;
      default = [ ];
      description = "Directories mounted read-only when running the container.";
    };

    mounts_read_write = mkOption {
      type = listOf str;
      default = [ ];
      description = "Directories mounted when running the container.";
    };
  };

  config = mkIf conf.enable {
    buildInputs = [ cont ];
    docker.mounts = [ "/nix" ];
  };
}
