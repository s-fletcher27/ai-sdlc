# ai-sdlc

A lightweight, reusable **AI Software Development Life Cycle (AI-SDLC)** framework built on **GitHub Actions** and **Claude Code**.

Target application repositories stay language-agnostic—bring your own container image, test command, and `CLAUDE.md` conventions while `ai-sdlc` provides the reusable workflows, agent prompts, and human-in-the-loop gates.

## How It Works

1. **Feature Issue (`status:new-feature`)** → **PM Agent** breaks the feature into numbered Stories, Acceptance Criteria, and Tasks (`gate:pm-review`).
2. **Human Gate 1** → Comment `/refine <feedback>` to iterate, or apply `status:pm-approved`.
3. **Architect Agent** → Inspects the target repo & `CLAUDE.md`, commits `docs/designs/issue-<N>.md` (one section per story) to branch `ai/issue-<N>` (`gate:design-review`).
4. **Human Gate 2** → Comment `/refine <feedback>` to adjust the design, or apply `status:design-approved`.
5. **Developer Agent** → Runs in your container image, implements **Story 1** on `feat/issue-<N>-story-1`, runs your test suite, and opens a Draft PR (`gate:pr-review`).
6. **Human Gate 3 (per story)** → Comment `/refine <feedback>` on the PR to iterate, or merge it. **Merging starts the next story.** The last story's PR closes the issue.

## Repository Structure

- `.github/workflows/reusable-01-pm.yml` — Stage 1 story & task breakdown (`workflow_call`)
- `.github/workflows/reusable-02-architect.yml` — Stage 2 technical design generator (`workflow_call`)
- `.github/workflows/reusable-03-developer.yml` — Stage 3 per-story containerised build, test & Draft PR (`workflow_call`)
- `prompts/` — Role prompts (`pm.md`, `architect.md`, `developer.md`)
- `scripts/` — Shared helpers (`context.sh`, `render-prompt.sh`) used by the workflows
- `examples/` — Files to copy into a target repo (`ai-sdlc.yml` caller workflow, `feature_request.yml` issue form)
- `docs/` — Architecture docs (`HLD.md`, `LLD.md`, `USAGE.md`)

## Quick Start

See [docs/USAGE.md](docs/USAGE.md) for full setup instructions, label creation commands, and the smoke test.
