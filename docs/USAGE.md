# Usage & Onboarding Guide

## 1. Framework Repo Setup (`ai-sdlc`)
1. Push this repository (`<OWNER>/ai-sdlc`) to GitHub (`main` branch).
2. Keep it **public** (it contains no secrets) so target repos on a personal account can call its reusable workflows and check out `prompts/` + `scripts/`. If you fork it, update `uses: <OWNER>/ai-sdlc/...` in the caller and pass `ai_sdlc_repo: <OWNER>/ai-sdlc` as an input.

## 2. Claude Code Token Setup
1. On your local machine with Claude Code installed, run:
   ```bash
   claude setup-token
   ```
2. Copy the generated OAuth token.
3. Add it to each **target repository** as an Actions secret named `CLAUDE_CODE_OAUTH_TOKEN`:
   ```bash
   gh secret set CLAUDE_CODE_OAUTH_TOKEN -R <OWNER>/<target-repo>
   ```

## 3. Target Application Repo Setup
1. **Create the labels:**
   ```bash
   gh label create "status:new-feature"     --color "0E8A16" --force
   gh label create "gate:pm-review"         --color "FBCA04" --force
   gh label create "status:pm-approved"     --color "1D76DB" --force
   gh label create "gate:design-review"     --color "FBCA04" --force
   gh label create "status:design-approved" --color "1D76DB" --force
   gh label create "gate:pr-review"         --color "FBCA04" --force
   gh label create "agent:working"          --color "D93F0B" --force
   ```
2. **Allow Actions to open PRs:** *Settings → Actions → General → Workflow permissions →* tick **"Allow GitHub Actions to create and approve pull requests"**. Without this, the Developer stage cannot open Draft PRs. Via CLI:
   ```bash
   gh api -X PUT repos/<OWNER>/<target-repo>/actions/permissions/workflow \
     -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
   ```
3. **Add a `CLAUDE.md`** at the repo root: stack, folder layout, how to install dependencies, lint and test commands.
4. **Copy `examples/feature_request.yml`** to `.github/ISSUE_TEMPLATE/feature_request.yml`.
5. **Copy `examples/ai-sdlc.yml`** to `.github/workflows/ai-sdlc.yml` and set the Developer inputs for your stack:
   | Stack | `container_image` | `setup_command` | `test_command` |
   | :--- | :--- | :--- | :--- |
   | Python | `python:3.12-slim` | `pip install -e '.[dev]'` | `pytest -q` |
   | Go | `golang:1.23-bookworm` | `go mod download` | `go test -race ./...` |
   | Node | `node:20-bookworm` | `npm ci` | `npm test` |

   The image must be Debian/Ubuntu-based (the build job installs `git` and `curl` with `apt-get`).

## 4. Running the Flow
| Gate | You do | Pipeline does |
| :--- | :--- | :--- |
| Start | Open an issue with the **Feature (AI-SDLC)** form (or add `status:new-feature`) | PM agent posts a numbered story breakdown → `gate:pm-review` |
| Gate 1 | Comment `/refine <feedback>`, or add `status:pm-approved` | Architect commits the design to `ai/issue-<N>` and posts it → `gate:design-review` |
| Gate 2 | Comment `/refine <feedback>`, or add `status:design-approved` | Developer builds Story 1 → Draft PR → `gate:pr-review` |
| Gate 3 (per story) | Comment `/refine <feedback>` **on the PR**, or mark ready & **merge** | Merge triggers Story K+1; after the last story it posts "complete" and the issue closes |

- **Retry after a failure:** re-apply the same `status:*` label (or re-comment `/refine`). Failure comments include a link to the run logs.
- Only repo owners/members/collaborators can drive the pipeline (`/refine` and new features from others are ignored).
- PRs opened by the pipeline use `GITHUB_TOKEN`, so your repo's own `pull_request` CI won't run on them automatically; the Developer stage runs `test_command` itself and reports the result in the PR. Push an empty commit or re-open the PR if you need your normal CI.
