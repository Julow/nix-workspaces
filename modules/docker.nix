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

  mount_args = flag: dirs: map (dir: "-v ${esc dir}:${esc dir}:${flag}") dirs;

  host_env_vars = lib.concatMap (v: [
    "-e"
    v
  ]) conf.host_env_vars;

  dot_git_rw =
    if conf.dot_git_rw then
      [ ]
    else
      [
        "-v"
        "\"$PWD/.git:/w/.git:ro\""
      ];

  # Use -u to make the files created in the container have the right ownership
  # on the host.
  cont = pkgs.writeShellScriptBin "cont" ''
    set -ex
    # Make sure all the mounted directories are created, otherwise docker
    # will create them with owner root.
    mkdir -p ${lib.concatMapStringsSep " " esc conf.mounts}
    # Use the tag to avoid loading the image each time
    image_tag="cont-$WORKSPACE:${baseNameOf image.outPath}"
    if ! docker image inspect "$image_tag" &>/dev/null; then
      docker image rm "cont-$WORKSPACE" 2>/dev/null || true
      ${image} -t "$image_tag" | docker image load
    fi
    if [[ $# -eq 0 ]]; then set bash; fi
    docker run \
      ${lib.concatStringsSep " \\\n  " conf.raw_docker_run_opts} \
      "$image_tag" "$(workspaces drv "${config.name}")" "$@"
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

    raw_docker_run_opts = mkOption {
      type = listOf str;
      default = [ ];
      description = "Options passed to 'docker run' in Bash syntax. Use with caution.";
    };

    host_env_vars = mkOption {
      type = listOf str;
      default = [ "PATH" ];
      description = "List of host environment variables passed to the container.";
    };

    dot_git_rw = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether .git should be mounted read-write. By default, it's mounted
        read-only to prevent arbitrary execution on the host via hooks.
      '';
    };
  };

  config = mkIf conf.enable {
    buildInputs = [ cont ];
    docker.mounts = [
      "/nix/store"
      "/run/current-system/sw"
    ];
    docker.raw_docker_run_opts = [
      "--rm"
      "-ti"
      "-v"
      "\"$PWD:/w\""
      "-u"
      "\"$(id -u):$(id -g)\""
      "-v"
      "/etc/passwd:/etc/passwd:ro"
      "-v"
      "/etc/group:/etc/group:ro"
      "--security-opt=no-new-privileges"
      "--cap-drop=ALL"
    ]
    ++ mount_args "ro" conf.mounts
    ++ mount_args "rw" conf.mounts_read_write
    ++ host_env_vars
    ++ dot_git_rw;
  };
}
