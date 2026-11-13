# ADR-0010: One writer plus an independent reviewer

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

"Done" was reported before it was verified at least three times: missed content, missed review findings, and a finding hidden in a review overview. In one project, a read-only test-reviewer agent that hadn't seen the work caught four blocking issues before the owner reviewed.

## Options

### Option 1: One implementing agent per branch, plus an independent read-only reviewer before the owner

- **Trade-offs:** No merge conflicts between writers; the reviewer runs the gates and ranks findings with fresh eyes; adds one review pass per PR.
- **Reversibility:** Easy. A role can be added or dropped.
- **Risk:** Low. Proven once already.

### Option 2: Several specialist agents writing in parallel on one task

- **Trade-offs:** Possibly faster; conflicting edits and unclear ownership of the result.
- **Reversibility:** Easy.
- **Risk:** Medium. Two writers on one task is how work gets lost.

### Option 3: No reviewer; the owner reviews everything

- **Trade-offs:** No extra pass; the owner becomes the first and only check.
- **Reversibility:** Easy.
- **Risk:** High. It's the setup that produced the premature "done" reports.

## Recommendation

Option 1: it's proven, and extra roles wait until the practice tasks show they pay off.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- `.claude/agents/reviewer.md` defines the reviewer (build step 3).
- **Updated by ADR-0064 (2026-11-12):** GitHub Copilot code review is now the independent reviewer, on every PR and every push to it; `.claude/agents/reviewer.md` is removed, and its checklist became `docs/code-review.md`.
- Planner, security, accessibility and docs reviews are skills the same agent runs at the right step; a role becomes a separate agent only on evidence. A separate test-writer is the first candidate.
- Parallel work means separate tasks on separate branches or worktrees.

## Pillars affected

Reliability: independent verification before merge. Operational Excellence: clear ownership of each change.

## Sources

- owner, 2026-11-01
