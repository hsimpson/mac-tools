#!/bin/sh

# Show merged Dependabot PRs grouped by assignee
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
  search(query: \"org:$1 label:dependencies is:pr is:merged merged:>${since}\", type: ISSUE, first: 100) {
    nodes {
      ... on PullRequest {
        title
        url
        mergedAt
        assignees(first: 1) { nodes { login } }
        repository { nameWithOwner }
      }
    }
  }
}" | jq -r --arg since "$since" --argjson days "$days" '
  .data.search.nodes
  | map(. + {assignee: .assignees.nodes[0].login})
  | group_by(.assignee)
  | map({assignee: .[0].assignee, count: length, prs: map({title, repo: .repository.nameWithOwner, mergedAt, url})})
  | sort_by(-.count)
  | . as $groups
  | ($groups[] | "\n👤 \(.assignee) — \(.count) PRs", (.prs[] | "  • [\(.repo)] \(.title)")),
    "\n---",
    "📊 Summary (last \($days) days, merged after \($since))",
    "  \($groups | map(.count) | add) PRs across \($groups | length) assignees",
    ($groups[] | "  • \(.assignee): \(.count)")
'