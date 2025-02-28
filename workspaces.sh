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

C_RESET=$'\033[0m'
C_GREEN=$'\033[0;32m'
C_RED=$'\033[0;31m'
C_GREY=$'\033[1;30m'
C_PURPLE=$'\033[0;35m'

workspace_status ()
{
  local wname=$1 p=$PREFIX/$1
  local prefix="" prefix_color="" status_color status
  local first_line line dirty=0
  if ! [[ -d $p ]]; then
    status=Uninitialized; status_color=$C_GREY
  elif ! [[ -d $p/.git ]]; then
    status=Initialized; status_color=$C_RESET
  elif ! {
    # The first line gives the checked-out branch and whether there are
    # unpushed changes
    read first_line
    while read line; do
      if ! [[ $line = [?]* ]]; then dirty=1; fi
    done
  } < <(git -C "$p" status -bs -unormal --no-renames --porcelain=v1); then
    status="Error getting git status"; status_color=$C_RED
  else
    first_line=${first_line#\#\# }
    status_color=$C_RESET; prefix="Clean"; prefix_color=$C_GREEN
    status="${first_line%%...*}"
    if [[ $first_line = *"]" ]]; then # Unpushed changes
      status="$status [${first_line##*[}"; status_color=$C_PURPLE; prefix_color=$C_PURPLE
    fi
    if [[ $dirty -eq 1 ]]; then prefix="Dirty"; prefix_color=$C_RED; fi
  fi
  printf "$prefix_color%-5s  $status_color%s  %s$C_RESET\n" \
    "$prefix" "$wname" "$status"
}

USAGE_OPEN="open <workspace name>"

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

  "status")
    for wname in "${!workspaces[@]}"; do
      workspace_status "$wname"
    done
    ;;

  *)
    cat <<EOF >&2
Usage: workspaces { open | list }

  $USAGE_OPEN
    Open the specified workspace. A directory in $PREFIX is created if it
    doesn't exist, the activation script is run and finally the shell is opened.

  list
    List workspaces.

  status
    Show status for each workspaces, including Git status.
EOF
    ;;
esac
