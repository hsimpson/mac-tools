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
search_query="org:$1 label:dependencies is:pr is:merged merged:>${since}"

results='[]'
cursor=''
has_next=true

while [ "$has_next" = "true" ]; do
  if [ -z "$cursor" ]; then
    page=$(gh api graphql -f query='
      query($q: String!) {
        search(query: $q, type: ISSUE, first: 100) {
          issueCount
          pageInfo { hasNextPage endCursor }
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
      }' -f q="$search_query")
  else
    page=$(gh api graphql -f query='
      query($q: String!, $cursor: String!) {
        search(query: $q, type: ISSUE, first: 100, after: $cursor) {
          issueCount
          pageInfo { hasNextPage endCursor }
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
      }' -f q="$search_query" -f cursor="$cursor")
  fi

  results=$(echo "$page" "$results" | jq -s '.[0].data.search.nodes + .[1]')
  has_next=$(echo "$page" | jq -r '.data.search.pageInfo.hasNextPage')
  cursor=$(echo "$page" | jq -r '.data.search.pageInfo.endCursor')
  issue_count=$(echo "$page" | jq -r '.data.search.issueCount')
done

echo "$results" | jq -r --arg since "$since" --argjson days "$days" --argjson issue_count "$issue_count" '
  .
  | map(. + {assignee: .assignees.nodes[0].login})
  | group_by(.assignee)
  | map({assignee: .[0].assignee, count: length, prs: map({title, repo: .repository.nameWithOwner, mergedAt, url})})
  | sort_by(-.count)
  | . as $groups
  | ($groups | map(.count) | add) as $total
  | ($groups[] | "\n👤 \(.assignee) — \(.count) PRs", (.prs[] | "  • [\(.repo)] \(.title)")),
    "\n---",
    "📊 Summary (last \($days) days, merged after \($since))",
    (if ($issue_count > $total) then "  ⚠️  GitHub search capped at 1000 results (\($issue_count) total match)" else empty end),
    "  \($total) PRs across \($groups | length) assignees",
    ($groups[] | "  • \(.assignee): \(.count)")
'