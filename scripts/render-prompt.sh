#!/usr/bin/env bash
# Renders a role prompt + run context into a single prompt on stdout.
# Usage: render-prompt.sh <prompt_file> <context_file>
# Placeholders replaced from env: {{ISSUE_NUMBER}} {{STORY_NUMBER}} {{TEST_COMMAND}} {{MODE}}
# Optional env REFINE_FEEDBACK is appended as authoritative human feedback.
# Pure bash (no sed/envsubst) so it works in minimal containers.
set -euo pipefail

prompt_file="$1"
context_file="$2"

content="$(cat "$prompt_file")"
content="${content//'{{ISSUE_NUMBER}}'/${ISSUE_NUMBER:-}}"
content="${content//'{{STORY_NUMBER}}'/${STORY_NUMBER:-}}"
content="${content//'{{TEST_COMMAND}}'/${TEST_COMMAND:-}}"
content="${content//'{{MODE}}'/${MODE:-}}"

printf '%s\n\n---\n\n# Run Context\n\n' "$content"
printf -- '- Repository: %s\n- Issue: #%s\n- Mode: %s\n' "${GITHUB_REPOSITORY:-}" "${ISSUE_NUMBER:-}" "${MODE:-initial}"
[ -n "${STORY_NUMBER:-}" ] && printf -- '- Story: %s\n' "$STORY_NUMBER"
printf '\n'

if [ -n "${REFINE_FEEDBACK:-}" ]; then
  printf '## Latest /refine feedback (authoritative — address this)\n\n%s\n\n' "$REFINE_FEEDBACK"
fi

cat "$context_file"
