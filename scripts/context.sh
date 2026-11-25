#!/usr/bin/env bash
# Builds a Markdown snapshot of an issue (and optionally a PR) for an agent run.
# Usage: context.sh <issue_number> [pr_number]
# Needs: gh CLI, GH_TOKEN, GITHUB_REPOSITORY
set -euo pipefail

issue="$1"
pr="${2:-}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"

echo "# Issue #${issue}"
echo
gh issue view "$issue" -R "$repo" --json title,body,comments --jq '
  "## Title\n\(.title)\n\n## Description\n\(.body // "(empty)")\n\n## Issue comments (oldest first)\n\n" +
  ([.comments[] | "### @\(.author.login) — \(.createdAt)\n\n\(.body)\n"] | join("\n"))'

if [ -n "$pr" ] && [ "$pr" != "0" ]; then
  echo
  echo "# Pull Request #${pr}"
  echo
  gh pr view "$pr" -R "$repo" --json title,body,comments,reviews --jq '
    "## Title\n\(.title)\n\n## Description\n\(.body // "(empty)")\n\n## PR comments (oldest first)\n\n" +
    ([.comments[] | "### @\(.author.login) — \(.createdAt)\n\n\(.body)\n"] | join("\n")) +
    "\n## Reviews\n\n" +
    ([.reviews[] | select(.body != "") | "### @\(.author.login) (\(.state))\n\n\(.body)\n"] | join("\n"))'
fi
