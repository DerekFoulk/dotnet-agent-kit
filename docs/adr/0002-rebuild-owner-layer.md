# ADR-0002: Rebuild the owner layer from the owner's stated rules

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The account-level skills (`engineering-standards`, `tdd-cycle`, `write-adr`) were written by an agent. They contain choices the owner never stated, and some contradict what he did state: a different mocking library, a different architecture-test library, Conventional Commits, and ".NET LTS" where he first said "latest stable".

## Options

### Option 1: Rebuild from the owner's own words; agent additions become proposals

- **Trade-offs:** Every owner-layer rule traces to something he said or ratified; the agent-added items need his review one by one.
- **Reversibility:** Easy. A proposal he rejects is simply retired.
- **Risk:** Low. Items stay `proposed` until ratified, so nothing unratified is in force.

### Option 2: Keep the account skills as they are

- **Trade-offs:** No review needed; but agents keep enforcing choices the owner never made.
- **Reversibility:** Easy.
- **Risk:** High. Contradictions with his stated preferences (ADR-0003, ADR-0005) stay in force.

## Recommendation

Option 1: the owner layer must hold only what the owner stated or ratified.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- Each rule's `layer` and `status` fields say whose rule it is and whether it is in force (`docs/standards/`).
- Agent-added items are marked `status: proposed` until the owner accepts them, usually by reviewing the PR that adds them.
- The account level keeps only the owner's profile and a pointer to the kit (brief §5).

## Pillars affected

Operational Excellence: rules are traceable, so they can be trusted and changed safely.

## Sources

- owner, 2026-11-01
