# ADR-0004: License check for commercial repos

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

ADR-0003 picks name-brand tools while they are free for the project's use. Some are free only for non-commercial work (FluentAssertions 8 under Xceed's community license), and some need a registered key below a revenue threshold (MediatR and AutoMapper since July 2025). Freelance work is commercial, and license compliance is a floor item that nothing overrides.

## Options

### Option 1: A floor check that flags non-free licenses when a repo is marked commercial

- **Trade-offs:** Personal repos keep the owner's preferred tools; commercial repos get a hard stop before shipping a license breach. Needs a per-repo "commercial" marker and a license list.
- **Reversibility:** Easy. The check is one CI step.
- **Risk:** Low. Its main failure is a missed license, which keeping the license list current reduces.

### Option 2: No check; rely on remembering

- **Trade-offs:** Nothing to build.
- **Reversibility:** Easy.
- **Risk:** High. A license breach in client work is a legal problem, not a style problem.

## Recommendation

Option 1: license compliance is a floor item, and it is cheap to check.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- A repo declares itself commercial; CI then fails on any package whose license isn't free for commercial use, naming its swap (for example AwesomeAssertions for FluentAssertions).
- Built after v0.1, with the `dotnet new` template and the sync step (brief §9). Until then the rule is advisory.

## Pillars affected

Security (compliance): no license breach ships. Cost Optimization: paid licenses are caught before they are owed.

## Sources

- owner, 2026-11-01
- https://www.jimmybogard.com/automapper-and-mediatr-commercial-editions-launch-today/, retrieved 2026-11-01
