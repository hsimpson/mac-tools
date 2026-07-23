#!/bin/sh

# Show merged Dependabot PRs grouped by merger
# Usage: dependabot-prs ORG [days]  (default: 14)
# Example: dependabot-prs my-org 30

if [ -z "$1" ]; then
  echo "Error: GitHub org or account name is required." >&2
  echo "Usage: $0 <org-or-account>" >&2
  exit 1
fi

days="${2:-14}"
since=$(date -v-${days}d '+%Y-%m-%d' 2>/dev/null || date -d "${days} days ago" '+%Y-%m-%d')

gh api graphql -f query="
{
  search(query: \"org:$1 author:app/dependabot is:pr is:merged merged:>=${since}\", type: ISSUE, first: 100) {
    nodes {
      ... on PullRequest {
        title
        url
        mergedAt
        mergedBy { login }
        repository { nameWithOwner }
      }
    }
  }
}" | jq -r '
  .data.search.nodes
  | group_by(.mergedBy.login)
  | map({mergedBy: .[0].mergedBy.login, count: length, prs: map({title, repo: .repository.nameWithOwner, mergedAt, url})})
  | sort_by(-.count)
  | .[] | "\n👤 \(.mergedBy) — \(.count) PRs", (.prs[] | "  • [\(.repo)] \(.title)")
'