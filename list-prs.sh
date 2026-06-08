#!/bin/sh

echo "List of all open PRs"

for repo in $(ls -1d *); do
  cd $repo
  # echo "Repo: $repo"
  prs=$(gh pr list --state open --json title,number,author,updatedAt --template '{{range .}}- [#{{.number}}]: {{.title}} - @{{.author.login}} ({{.updatedAt}}){{"\n"}}{{end}}')

  if [ ! -z "$prs" ]; then
    echo "Repo: $repo"
    echo "$prs"
    echo "\n"
  fi
  cd '..'
done