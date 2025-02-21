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

# Remove remotes set using the old method
remove_legacy_remote ()
{
  local name="$1" url="$2" role="$3"
  local old_url=${old_remotes["$name-$role"]}
  if [[ "$url" = "$old_url" ]]; then
    git remote remove "$name"
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

# Previous versions of nix-workspaces used to make .git/info/exclude into a
# symlink to the nix store. Ignore rules are now set in a different way.
remove_legacy_exclude_file ()
{
  local excl=.git/info/exclude
  if [[ -L $excl ]] && [[ $(readlink "$excl") = "/nix/store/"*"-gitignore" ]]; then
    rm "$excl"
  fi
}
