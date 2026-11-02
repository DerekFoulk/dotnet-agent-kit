# ADR-0022: Making release-please work with merge commits

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

release-please reads Conventional Commits and officially recommends squash merges. Its commit-override feature doesn't work with plain merges, and there are reports that it misses commits that arrive through a merge commit. The kit uses merge commits only (ADR-0007).

## Options

### Option 1: Conventional PR titles, merge commit message set to the PR title, proven by a spike

- **Trade-offs:** A CI check requires every PR title to be a Conventional Commit, and the repo's default merge commit message is the PR title, so each merge commit itself carries `feat:` or `fix:`. One more CI check and one repo setting.
- **Reversibility:** Easy.
- **Risk:** Medium until the spike proves release PR → tag → MinVer version end to end.

### Option 2: Switch to squash merges for release-please

- **Trade-offs:** release-please's supported mode; contradicts ADR-0007 and erases red→green history.
- **Reversibility:** Squashed history can't be recovered.
- **Risk:** High.

### Option 3: Drop release-please for a history-walking tool or a small tagging script

- **Trade-offs:** Full control; more to build and maintain.
- **Reversibility:** Easy.
- **Risk:** Medium. This is the fallback if the spike fails.

## Recommendation

Option 1, with Option 3 as the fallback if the spike fails.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- `kit-checks.reusable.yml` checks PR titles (build step 4); the merge-commit-message setting changes only with the owner's OK.
- Build step 5 spikes the release flow before `release.yml` is relied on.

## Pillars affected

Operational Excellence: automated releases without giving up the history ADR-0007 protects.

## Sources

- owner, 2026-11-01
- https://github.com/googleapis/release-please, retrieved 2026-11-01
