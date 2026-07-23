#!/bin/sh

if [ -z "$1" ]; then
  echo "Error: GitHub org or account name is required." >&2
  echo "Usage: $0 <org-or-account>" >&2
  exit 1
fi

gh repo list "$1" --no-archived --limit 1000 --json sshUrl --jq '.[].sshUrl' | xargs -L1 gh repo clone