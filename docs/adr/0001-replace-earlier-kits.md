# ADR-0001: Replace the earlier kits with dotnet-agent-kit

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner's engineering setup was rebuilt three times, once per project, and three kits exist: an installer kit with standards and skills (`ai-dev-kit`), a kit handed to a coding agent (instructions, ADRs, CI, test gates), and a third project's skills and intake questionnaire. They overlap and already disagree, so every new repo starts by choosing between them.

## Options

### Option 1: One new kit that replaces all of them

- **Trade-offs:** One source of truth, rebuilt from the owner's own statements; costs a deliberate build and the migration of existing repos.
- **Reversibility:** Moderate. The earlier kits are archived, not deleted, so their content stays available.
- **Risk:** Low. The best parts (the installer's managed-block design, the most mature repo's enforcement config) are carried over rather than rewritten.

### Option 2: Keep the earlier kits and reconcile them

- **Trade-offs:** No new repo; but three copies keep drifting, and none was built from the owner's own words.
- **Reversibility:** Easy to start, hard to finish: reconciliation never ends while three copies exist.
- **Risk:** High. The disagreements that prompted this work stay in place.

## Recommendation

Option 1: one kit ends the drift, and it keeps what already works.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- `dotnet-agent-kit` is the only kit. The earlier kits are archived once their useful parts are carried over.
- The installer's managed-block design and the mature repo's enforcement config are the starting points (brief §1, §5).

## Pillars affected

Operational Excellence: one method, one place to change it.

## Sources

- owner, 2026-11-01
