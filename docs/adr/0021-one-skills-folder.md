# ADR-0021: One skills folder for every tool

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The kit's skills (`start-work`, `plan-checklist`, `tdd-cycle`, `write-adr`, `finish-work`) must reach Claude Code and Copilot. Research found that Claude Code, Visual Studio 2026 and VS Code all read `.claude/skills/<name>/SKILL.md`. Whether the Copilot coding agent reads that folder is unconfirmed.

## Options

### Option 1: One folder, `.claude/skills/`, with no generated copies

- **Trade-offs:** One copy that can't drift; depends on the coding agent also reading it, which a spike confirms.
- **Reversibility:** Easy. The sync step can add a copy if needed.
- **Risk:** Low to medium until the spike.

### Option 2: Generate a copy per tool (`.github/skills/` as well)

- **Trade-offs:** Works for every tool now; copies can drift, and a drift check is then needed.
- **Reversibility:** Easy.
- **Risk:** Medium. Drift between copies is the problem this kit exists to end.

## Recommendation

Option 1: all three confirmed tools read it; copies are added only if the spike shows the coding agent doesn't.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- Skills live in `.claude/skills/` only (build step 3).
- The build step 5 spike checks the Copilot coding agent; if it doesn't read the folder, the sync step copies skills to `.github/skills/`.
- **Spike result (2026-11-04):** it does. GitHub's docs list `.claude/skills` as a project skills folder, and in a live run (issue #7, draft PR #8) the coding agent listed all six kit skills at their `.claude/skills/` paths and quoted `write-adr` word for word. No copy is needed. Details: `spikes/copilot-skills/README.md`.

## Pillars affected

Operational Excellence: one source for every tool.

## Sources

- owner, 2026-11-01
- https://code.claude.com/docs/en/skills, retrieved 2026-11-01
- https://devblogs.microsoft.com/visualstudio/agent-skills-in-visual-studio, retrieved 2026-11-01
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills, retrieved 2026-11-04
