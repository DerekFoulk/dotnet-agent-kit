# ADR-0013: Keep the kit repo private

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The kit holds the owner's engineering method. It is meant to stay domain-neutral, but its corrections log and practice results describe how agents behaved on his work. Template and package installs must still work for him.

## Options

### Option 1: Private repo `dotnet-agent-kit`

- **Trade-offs:** The owner controls who sees it; installs work for him with his GitHub sign-in. Some GitHub features (secret scanning, environment reviewers) aren't available for private personal repos (ADR-0023, ADR-0024).
- **Reversibility:** Easy. A private repo can be made public later.
- **Risk:** Low.

### Option 2: Public repo

- **Trade-offs:** Free GitHub security features and easy sharing; everything in it is visible to everyone, permanently.
- **Reversibility:** Hard. Published content may be copied or indexed even after it is made private.
- **Risk:** Medium. One slip of non-neutral content becomes public.

## Recommendation

Owner decision; private is the reversible choice.

## Decision

Decided by the owner: private, named `dotnet-agent-kit` (owner, 2026-11-01).

## Consequences

- The repo is `DerekFoulk/dotnet-agent-kit`, private.
- Features missing on private personal repos are replaced in the kit itself (ADR-0023, ADR-0024).

## Pillars affected

Security: access stays limited to the owner.

## Sources

- owner, 2026-11-01
