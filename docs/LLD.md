# Low-Level Design (LLD) — `ai-sdlc` Reusable Framework

## 1. Repository Layout
```text
ai-sdlc/
├── README.md
├── docs/
│   ├── HLD.md
│   ├── LLD.md
│   └── USAGE.md
├── prompts/
│   ├── pm.md
│   ├── architect.md
│   └── developer.md
├── scripts/
│   ├── context.sh          # issue/PR → Markdown context snapshot (gh CLI)
│   └── render-prompt.sh    # fills {{ISSUE_NUMBER}} {{STORY_NUMBER}} {{TEST_COMMAND}} {{MODE}} + appends context
├── examples/
│   ├── ai-sdlc.yml          # caller workflow for target repos
│   └── feature_request.yml  # issue form that applies status:new-feature
└── .github/
    └── workflows/
        ├── reusable-01-pm.yml
        ├── reusable-02-architect.yml
        └── reusable-03-developer.yml
```

## 2. Label State Machine & Transitions
| Trigger | Action | Labels |
| :--- | :--- | :--- |
| `status:new-feature` **added** (trusted issue author) | PM agent posts breakdown comment | − `status:new-feature`, + `gate:pm-review` |
| `/refine ...` on issue with `gate:pm-review` | PM agent re-runs with full thread | keep `gate:pm-review` |
| `status:pm-approved` **added** | Architect writes `docs/designs/issue-<N>.md` on `ai/issue-<N>`, posts it | − `status:pm-approved`, − `gate:pm-review`, + `gate:design-review` |
| `/refine ...` on issue with `gate:design-review` | Architect updates design on `ai/issue-<N>` | keep `gate:design-review` |
| `status:design-approved` **added** | Developer builds next unmerged story K (Story 1 first) → Draft PR | − `status:design-approved`, − `gate:design-review`, + `gate:pr-review` (issue + PR) |
| `/refine ...` on story PR with `gate:pr-review` | Developer updates `feat/issue-<N>-story-<K>` | keep `gate:pr-review` |
| Story PR **merged** | Developer builds Story K+1 → Draft PR; if none left, posts "complete" | keep / − `gate:pr-review` when complete |
| Any agent run | lock indicator | + `agent:working` at start, − in `always()` cleanup |

**Failure:** trigger labels are consumed at the start, gate labels are only added on success, and a failure comment links the run logs. **Retry** = re-apply the same `status:*` label, or comment `/refine` again.

## 3. Branches & Story Numbering
- `ai/issue-<N>` — design branch, written only by the Architect stage.
- `feat/issue-<N>-story-<K>` — one per story. Story 1 branches from `ai/issue-<N>` (its PR carries the design doc to the default branch). Story K>1 branches from the default branch after Story K-1 is merged.
- Stories are identified by `### Story <K>: <Title>` headings in the design doc. The Developer workflow uses them to pick the story title, detect the last story (adds `Closes #N`), and detect completion.
- On `status:design-approved`, K = 1 + number of merged `feat/issue-<N>-story-*` PRs (so re-applying the label retries the current story).

## 4. Workflow Contracts (`workflow_call`)
All reusable workflows read issue/PR numbers from the caller's event payload (`github.event`), take `secrets.CLAUDE_CODE_OAUTH_TOKEN` (required), and accept `ai_sdlc_repo` (default `s-fletcher27/ai-sdlc`) and `ai_sdlc_ref` (default `main`) so they can fetch `prompts/` and `scripts/`.

- **`reusable-01-pm.yml`** — runner: `ubuntu-latest`
  - Inputs: `max_turns` (default `10`).
  - Permissions: `contents: read`, `issues: write`.
  - Agent tools: `Read,Glob,Grep,Write`. Output: `.ai-sdlc-out/pm_output.md` → posted as issue comment.
- **`reusable-02-architect.yml`** — runner: `ubuntu-latest`
  - Inputs: `max_turns` (default `20`).
  - Permissions: `contents: write`, `issues: write`.
  - Agent tools: `Read,Glob,Grep,Write,Edit`. Output: `docs/designs/issue-<N>.md` (must contain `### Story 1`); only that file is committed to `ai/issue-<N>`; design posted in an issue comment.
- **`reusable-03-developer.yml`** — jobs `resolve` (runner) → `build` (container) → `publish` (runner)
  - Inputs: `container_image` (default `ubuntu:24.04`, must be Debian/Ubuntu-based), `setup_command` (default `""`), `test_command` (default `echo 'No test command configured'`), `max_turns` (default `40`).
  - Permissions: `contents: write`, `issues: write`, `pull-requests: write`.
  - Agent tools: `Read,Glob,Grep,Write,Edit,MultiEdit,Bash`. Output: code on `feat/issue-<N>-story-<K>`, `.ai-sdlc-out/pr_body.md`; workflow runs `test_command` itself, commits (`WIP:` prefix if tests fail), pushes, opens/updates the Draft PR.

## 5. Guardrails
- **Triggers fire on label *added*** (`github.event.label.name`), not label presence — no double-firing on `opened`+`labeled`, and unrelated label edits don't re-run stages.
- **No self-triggering loops:** all label, comment, push and PR operations use `GITHUB_TOKEN`, which GitHub never lets trigger further workflow runs. The only events that advance the pipeline are human actions.
- **Concurrency:** caller jobs share `concurrency: ai-sdlc-<issue-or-PR-number>` (no cancel), so one stage runs at a time per issue/PR. `agent:working` is a visible indicator, not the lock.
- **Authorisation:** `/refine` only from `OWNER`/`MEMBER`/`COLLABORATOR`; `status:new-feature` only acts on issues opened by those roles. Approval labels need triage access anyway.
- **Bounded runs:** `--max-turns` per stage and `timeout-minutes` per job.
- **Agent sandboxing:** agents never run git push; the Developer container checkout uses `persist-credentials: false`; Architect commits only the design file; Developer edits to `.github/workflows/` are discarded.
- **Untrusted text** (issue bodies, comments) only reaches scripts through `env:`, never `${{ }}` interpolation inside `run:`.

## 6. Context Assembly & Failure Handling
- `scripts/context.sh` writes the issue title, body and all comments (and, for PR refinements, the PR body, comments and reviews) to `.ai-sdlc-out/context.md`. `.ai-sdlc-out/` is excluded via `.git/info/exclude` so it is never committed.
- `scripts/render-prompt.sh` fills the prompt placeholders and appends the context plus the latest `/refine` feedback.
- `if: always()` cleanup removes `agent:working` so an issue is never left looking locked; `if: failure()` posts a comment with the run link and retry instructions.
- Target repo caller workflow must grant `permissions:` per job (the repo default token may be read-only) and pass `CLAUDE_CODE_OAUTH_TOKEN` in `secrets:`.
