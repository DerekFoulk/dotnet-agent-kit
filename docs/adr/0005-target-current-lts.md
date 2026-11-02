# ADR-0005: Target the current .NET LTS

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner first said "latest stable", then clarified on 2026-11-01 that LTS is the right default, with room for a newer non-LTS (STS) release in the rare case he really wants one of its features. .NET 10 (LTS) is supported until November 2028. .NET 11 (STS) is due November 2026 with 24 months of support. .NET 8 and .NET 9 both end support on November 10, 2026.

## Options

### Option 1: Current LTS by default, latest patch; STS only by an ADR naming the feature

- **Trade-offs:** A three-year support window and fewer forced upgrades; a newer feature waits for the next LTS unless an ADR justifies it.
- **Reversibility:** Easy. A repo moves to STS by ADR, and back at the next LTS.
- **Risk:** Low.

### Option 2: Always the latest release, LTS or STS

- **Trade-offs:** Newest features first; a mandatory upgrade every 24 months on STS releases.
- **Reversibility:** Easy.
- **Risk:** Medium. More frequent framework upgrades across every repo.

## Recommendation

Option 1: it matches the owner's clarification, and the ADR escape hatch covers the rare exception.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- Projects target `net10.0`; `global.json` pins the latest .NET 10 SDK patch (ADR-0025).
- CI warns before any target nears end of support.
- A move to an STS release needs an ADR that names the feature it needs.

## Pillars affected

Reliability and Security: supported frameworks get security patches. Operational Excellence: fewer forced upgrades.

## Sources

- owner, 2026-11-01
- https://github.com/dotnet/core, retrieved 2026-11-01
