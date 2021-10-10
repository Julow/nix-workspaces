# Not a standalone shell script

# Read old git remotes
declare -A old_remotes
while read name url rest; do
  old_remotes+=(["$name"]="$url")
done < <(git remote -v)

# Sync remotes
update_remote ()
{
  local name="$1" url="$2"
  local old_url=${old_remotes[$name]}
  if ! [[ "$url" = "$old_url" ]]; then
    if [[ -z "$old_url" ]]; then
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
  local dst="$1" main="MAIN"
  local main_ref="refs/heads/$dst"
  if [[ `git symbolic-ref "$main" 2>/dev/null` != $main_ref ]]; then
    git symbolic-ref "$main" "$main_ref"
    git config init.defaultBranch "$dst"
  fi
}
