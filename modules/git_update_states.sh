# Not a standalone shell script

# Read old git remotes
declare -A old_remotes
if [[ -d .git ]]; then # When called from the initialization script
  while read name url role; do
    role=${role#(}
    role=${role%)}
    old_remotes+=(["$name-$role"]="$url")
  done < <(git remote -v)
fi

# Sync remotes
update_remote ()
{
  local name="$1" url="$2" role="$3"
  local old_url=${old_remotes["$name-$role"]}
  if ! [[ "$url" = "$old_url" ]]; then
    if [[ $role = push ]]; then
      git remote set-url --push "$name" "$url"
    elif [[ -z "$old_url" ]]; then
      # This check is only done for fetch URLs, which should be updated first.
      git remote add "$name" "$url"
    else
      git remote set-url "$name" "$url"
    fi
  fi
}

# Sync the MAIN symbolic ref
# Also update the 'init.defaultBranch' config in case it's used by some scripts
update_default_branch ()
{
  local dst="$1"
  local main_ref="refs/heads/$dst"
  if [[ `git symbolic-ref MAIN 2>/dev/null` != $main_ref ]]; then
    git symbolic-ref MAIN "$main_ref"
    git config init.defaultBranch "$dst"
    echo "Using '$dst' as the default branch." >&2
  fi
}

guess_default_branch ()
{
  local default=$(git config init.defaultBranch)
  for guess in "$default" main master trunk; do
    if [[ -e .git/refs/heads/$guess ]]; then
      update_default_branch "$guess"
      return
    fi
  done
}
