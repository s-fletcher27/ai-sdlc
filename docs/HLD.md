# High-Level Design (HLD) — `ai-sdlc` Reusable Framework

## 1. Purpose & Scope
`ai-sdlc` is a reusable GitHub Actions framework that turns a high-level GitHub Feature Issue into a broken-down backlog, a committed technical design document, and one tested Draft Pull Request per story—using GitHub Actions jobs and the Claude Code CLI (headless `claude -p`) with explicit human approval and `/refine` loops at every gate. Deployment is out of scope for the initial framework.

## 2. System Context
```text
[Developer / User]
       │  Opens Feature Issue (status:new-feature)
       │  Comments `/refine ...`, applies approval labels, merges story PRs
       ▼
[Target App Repository] ──(workflow_call)──► [ai-sdlc Framework Repo]
       │                                           ├── reusable-01-pm.yml
       │  • Issues & Labels (state machine)        ├── reusable-02-architect.yml
       │  • CLAUDE.md (stack & conventions)        ├── reusable-03-developer.yml
       │  • ai/issue-<N> (design branch)           ├── prompts/{pm,architect,developer}.md
       │  • feat/issue-<N>-story-<K> + Draft PRs   └── scripts/{context,render-prompt}.sh
       ▼
[GitHub Actions Hosted Runners]
       │  PM/Architect on the runner; Developer build inside the target's container image
       ▼
[Claude Code CLI + Pro/Max OAuth token (CLAUDE_CODE_OAUTH_TOKEN)]
```

## 3. Core Lifecycle & Human Gates
1. **Intake & Breakdown (Gate 1):** Adding `status:new-feature` triggers the PM agent to post numbered Stories, Acceptance Criteria, and Tasks, then sets `gate:pm-review`. Human comments `/refine ...` to iterate or applies `status:pm-approved`.
2. **Technical Design (Gate 2):** `status:pm-approved` triggers the Architect agent to inspect the target repo and `CLAUDE.md`, write `docs/designs/issue-<N>.md` with one `### Story K` section per story, commit it to `ai/issue-<N>`, and set `gate:design-review`. Human comments `/refine ...` or applies `status:design-approved`.
3. **Build, Test & Draft PR per Story (Gate 3):** `status:design-approved` triggers the Developer agent inside the target repo's container image to implement **Story 1** on `feat/issue-<N>-story-1`. The workflow re-runs the test command, then opens a Draft PR with `gate:pr-review`. Human comments `/refine ...` on the PR to iterate, or merges it. **Merging a story PR triggers the next story**; when no story is left, the pipeline posts "complete". The last story's PR carries `Closes #N`.

## 4. Key Architectural Decisions
- **Reusable workflows (`workflow_call`) over copied scripts:** Centralises orchestration and prompt updates in `ai-sdlc` while letting target repos stay thin (one caller workflow + labels + `CLAUDE.md`).
- **Label-driven state machine:** Avoids external databases or polling workers; GitHub Issues, PRs and branch names hold all workflow state and human feedback.
- **One PR per story, built sequentially:** Keeps reviews small. Later stories build on merged earlier ones, so no stacking or merge conflicts between story branches.
- **Per-target container & test injection:** Target repos supply `container_image`, `setup_command` and `test_command` so the same engine supports Python, Go, Node, or any other stack.
- **Workflow owns git, agent owns code:** Agents only edit files. The workflow creates branches, commits, pushes, opens PRs, and re-runs tests independently of the agent's own claims.
- **Claude Code CLI directly (not `claude-code-action`):** Headless `claude -p` with an explicit `--allowedTools` list and `--max-turns`, installed via the native installer. Fewer moving parts inside arbitrary containers.
- **Guardrails by default:** see LLD §5.
