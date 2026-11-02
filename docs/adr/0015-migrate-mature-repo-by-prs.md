# ADR-0015: Migrate the most mature existing repo by PRs

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner's most mature repo already has most of the enforcement the kit standardizes. He asked whether to restart it on the new kit, partly to get fresh PR numbers.

## Options

### Option 1: Migrate it with ordinary PRs, keeping its history

- **Trade-offs:** History and PR conversations stay; the migration is a series of reviewable PRs. PR numbers continue from where they are.
- **Reversibility:** Easy. Each PR can be reverted.
- **Risk:** Low.

### Option 2: Rebuild it from scratch on the kit

- **Trade-offs:** A clean start; it would end in much the same code, and all history and review context are lost.
- **Reversibility:** Hard.
- **Risk:** Medium. Rework with little gain.

### Option 3: A new GitHub repo with the same git history pushed to it

- **Trade-offs:** Fresh PR numbers with commit history kept; loses the old PR conversations, and deleting the old repo can't be undone.
- **Reversibility:** Hard once the old repo is deleted.
- **Risk:** Medium. Needs the owner's explicit OK at migration time.

## Recommendation

Option 1. PR numbers can't stay in step with merges anyway (issues, Dependabot PRs and closed PRs share the counter), and merge commits already record their PR numbers.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- The mature repo moves onto the kit through ordinary PRs, after v0.1 (brief §9).
- Option 3 stays available, once, at migration time, with the owner's explicit OK.

## Pillars affected

Operational Excellence: history and review context are preserved.

## Sources

- owner, 2026-11-01
