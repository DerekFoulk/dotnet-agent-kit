# ADR-0016: Azure Well-Architected Framework as the architecture practice

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner pointed to Microsoft's architect-role page in the Azure Well-Architected Framework (WAF). It is mostly about process: requirements, a design spec with diagrams, ADRs that record trade-offs and rejected options, proofs of concept for risky parts, supportability, avoiding deprecated components, and weighing five pillars (reliability, security, cost optimization, operational excellence, performance efficiency). Plans in one project were rejected twice for missing standard concerns such as health checks and telemetry.

## Options

### Option 1: Adopt WAF and turn its expectations into templates and checks

- **Trade-offs:** The ADR template requires options with trade-offs; the plan checklist uses the five pillars as headings; diagrams live as code; deprecated packages fail CI; PSRule for Azure validates Bicep in the hosting profile. More structure in every plan and ADR.
- **Reversibility:** Easy. Templates and checks can be relaxed.
- **Risk:** Low.

### Option 2: No named framework; plans cover concerns case by case

- **Trade-offs:** Lighter plans; the gaps that caused two plan rejections stay possible.
- **Reversibility:** Easy.
- **Risk:** Medium.

## Recommendation

Option 1: most of the architect-role page can be made checkable, and the pillars give plans a complete checklist.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- `docs/adr/0000-template.md` requires Options (with trade-offs, reversibility, risk), Recommendation and Pillars affected; `tools/Test-AdrSections.ps1` checks them.
- The `plan-checklist` skill uses the five pillars as headings (build step 3).
- `docs/architecture/` holds Mermaid diagrams, updated in the same PR as the change.
- Spikes live in `spikes/` and are never merged into production code as-is.
- CI fails on deprecated packages (build step 4); preview packages need an ADR.

## Pillars affected

All five: this decision is what makes them part of every plan and ADR.

## Sources

- owner, 2026-11-01
- https://learn.microsoft.com/en-us/azure/well-architected/architect-role/fundamentals, retrieved 2026-11-01
