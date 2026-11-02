# ADR-0012: Distribution: template, NuGet config package and sync

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The kit must reach new and existing repos, and its updates must reach every repo that uses it in one PR (success criterion S4). Templates alone never update. A repo's `.editorconfig` overrides analyzer settings shipped in a package, so not everything can ship through NuGet.

## Options

### Option 1: `dotnet new` template pack to start, a NuGet config package plus a sync step to update

- **Trade-offs:** Templates appear in Visual Studio's Create a new project dialog; build config updates with a package bump; files a package can't own (`.editorconfig`, agent files, CI callers) are synced into managed blocks. Three mechanisms to maintain.
- **Reversibility:** Moderate.
- **Risk:** Low to medium. The sync step must be idempotent and leave project-owned text alone.

### Option 2: A GitHub template repository only

- **Trade-offs:** Simplest to start; nothing updates after creation, so repos drift immediately.
- **Reversibility:** Easy.
- **Risk:** High for S4.

### Option 3: Copy files by hand

- **Trade-offs:** No tooling; every update is manual and error-prone.
- **Reversibility:** Easy.
- **Risk:** High. This is how the earlier kits drifted.

## Recommendation

Option 1: each piece uses the mechanism that can actually update it.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- v0.1 copies `kit/core` by hand; the sync step, the template and the NuGet package follow in that order (brief §9).
- CI jobs ship as reusable GitHub Actions workflows called with a pinned ref.
- An optional GitHub template repo may still exist for convenience.

## Pillars affected

Operational Excellence: updates are one PR, not a manual hunt.

## Sources

- owner, 2026-11-01
- https://learn.microsoft.com/dotnet/core/tools/templates, retrieved 2026-11-01
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/configuration-files, retrieved 2026-11-01
