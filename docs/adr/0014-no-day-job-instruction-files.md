# ADR-0014: Leave out instruction files from the owner's day job

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner has agent instruction files from his day job. They might hold useful general practice, but they may also contain employer-specific or confidential content, and the brief forbids employer content in the kit unless he has removed anything employer-specific.

## Options

### Option 1: Skip them

- **Trade-offs:** No risk of employer content in the kit; any general ideas in them are lost unless the owner restates them himself.
- **Reversibility:** Easy. He can bring parts in later.
- **Risk:** Low.

### Option 2: Import their general parts after the owner removes employer-specific content

- **Trade-offs:** Possibly useful practice; needs his careful review of each file first.
- **Reversibility:** Hard once content is committed and pushed.
- **Risk:** Medium. A confidential detail could slip through.

## Recommendation

Owner decision; skipping is the safe default.

## Decision

Decided by the owner: skip them (owner, 2026-11-01).

## Consequences

- No day-job files are read or imported into the kit.
- If the owner later wants an idea from them, he states it himself, and it enters the owner layer like any other rule.

## Pillars affected

Security (confidentiality): no employer content enters the kit.

## Sources

- owner, 2026-11-01
