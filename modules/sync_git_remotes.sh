#!/usr/bin/env bash

set -e

declare -A new_remotes
while read name url rest; do new_remotes+=([$name]="$url"); done

declare -A old_remotes
while read name url rest; do old_remotes+=([$name]="$url"); done \
  < <(git remote -v)

for r in "${!new_remotes[@]}" "${!old_remotes[@]}"; do
  new_url=${new_remotes[$r]}
  old_url=${old_remotes[$r]}
  if [[ -z "$old_url" ]]; then
    git remote add "$r" "$new_url"
  elif [[ -z "$new_url" ]]; then
    git remote remove "$r"
  elif ! [[ "$new_url" = "$old_url" ]]; then
    git remote set-url "$r" "$new_url"
  fi
done
