#!/bin/sh
# list all stashes

for repo in $(ls -1d *); do
  cd $repo

  stashes=$(git stash list)
  if [ ! -z "$stashes" ]; then
    echo "Repo: $repo"
    echo "$stashes\n"
  fi
  cd '..'
done
