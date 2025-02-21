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

guess_default_branch ()
{
  local default=$(git config init.defaultBranch)
  for guess in "$default" main master trunk; do
    if [[ -e .git/refs/heads/$guess ]]; then
      git symbolic-ref MAIN "refs/heads/$guess"
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
