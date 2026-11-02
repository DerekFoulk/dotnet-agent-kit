# ADR-0007: GitHub Flow with merge commits only

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner historically used GitFlow with no fast-forward and no squash, and accepted GitHub Flow ("GitHub Flow is fine"). He is "not a huge fan of the rebase and merge", and wants history to tell the story as it happened. In one project an agent picked rebase-merge, the owner reversed it, and history was rebuilt three times. That is the most expensive repeated correction on record.

## Options

### Option 1: GitHub Flow, merge commits only, enforced by settings and a ruleset

- **Trade-offs:** Short-lived branches off `main`, and every red and green commit plus the PR boundary stays in history; history is longer than with squash.
- **Reversibility:** Easy. A repo setting and a ruleset.
- **Risk:** Low. Enforcement removes the choice that caused the rework.

### Option 2: GitHub Flow with squash merges

- **Trade-offs:** One tidy commit per PR, and release-please's recommended mode; but it erases the red→green evidence the owner's TDD rule depends on.
- **Reversibility:** Squashed history can't be recovered.
- **Risk:** High. It contradicts the owner's stated rule.

### Option 3: Keep GitFlow

- **Trade-offs:** Fits supporting several released versions at once, which no current project needs; more branches and ceremony for continuously delivered software.
- **Reversibility:** Moderate.
- **Risk:** Medium. Its author recommends a simpler flow for continuous delivery.

## Recommendation

Option 1: it keeps the history the owner wants and makes the costly mistake impossible.

## Decision

Accepted as recommended. Merge strategy stated by the owner (owner, 2026-10-26).

## Consequences

- Squash and rebase merges are disabled in repo settings; a ruleset's merge-method rule allows merge commits only (build step 4, with the owner's OK).
- `main` is protected; work happens on branches with PRs; agents merge only when the owner says so for that PR.
- If a project ever needs to support several released versions, a maintenance branch is cut from a release tag at that point.

## Pillars affected

Operational Excellence: a faithful, auditable history.

## Sources

- owner, 2026-10-26
- https://github.blog/changelog/2024-12-04-pull-request-merge-method-rule-public-preview, retrieved 2026-11-01
- https://nvie.com/posts/a-successful-git-branching-model/, retrieved 2026-11-01
