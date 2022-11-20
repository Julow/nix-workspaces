# this is not a standalone shell script.
: ${workspaces[@]:?This script is not intended to be executed}
: ${PREFIX:?}

set -e

open_workspace ()
{
  local wname="$1" pkg p
  p=$PREFIX/$wname
  pkg=${workspaces[$wname]:?Workspace $wname not found.}

  if ! [[ -d "$p" ]]; then
    mkdir -p "$p" # side effect
    # First time opening this workspace, call 'workspace-init'
    cd "$p"
    "$pkg"/bin/workspace-init
  fi

  cd "$p"
  "$pkg"/bin/workspace-activate
}

USAGE_OPEN="open <workspace name>"
USAGE_LIST="list"

cmd=$1
shift

case "$cmd" in
  "open")
    wname=${1:?Usage: workspaces $USAGE_OPEN}
    open_workspace "$wname"
    ;;

  "list")
    for wname in "${!workspaces[@]}"; do
      echo "$wname"
    done
    ;;

  *)
    cat <<EOF >&2
Usage: workspaces { open | list }

  $USAGE_OPEN
    Open the specified workspace. A directory in $PREFIX is created if it
    doesn't exist, the activation script is run and finally the shell is opened.

  $USAGE_LIST
    List workspaces.
EOF
    ;;
esac
