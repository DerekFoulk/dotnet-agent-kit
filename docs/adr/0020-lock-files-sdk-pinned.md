# ADR-0020: Package lock files on, SDK pinned

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

Lock files (`packages.lock.json`) record the exact version and a content hash of every package, direct and transitive, so CI restores exactly what was tested and rejects a tampered package. The owner has seen them churn. That churn has a known SDK cause (dotnet/sdk#38200, still open): packages the SDK adds implicitly for trimming, AOT and Blazor WebAssembly change with every SDK patch, so locked restore fails on machines with a different SDK.

## Options

### Option 1: Lock files on by default, SDK pinned; off per project only where SDK-implicit packages churn

- **Trade-offs:** Exact, tamper-checked restores; churn is avoided by pinning the SDK (ADR-0025) and by switching lock files off only for the affected projects, where central package management still fixes versions.
- **Reversibility:** Easy. One property per project.
- **Risk:** Low.

### Option 2: Lock files off everywhere

- **Trade-offs:** No churn; transitive versions can move between restores, and a tampered package isn't detected by hash.
- **Reversibility:** Easy.
- **Risk:** Medium (supply chain).

## Recommendation

Option 1: the integrity benefit stays, and the known cause of churn is handled directly.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- `Directory.Build.props` sets `RestorePackagesWithLockFile`, and `RestoreLockedMode` when `CI=true` (since build step 1).
- Dependency updates regenerate lock files in the same PR. Dependabot misses projects affected through project references, so a workflow refreshes lock files on Dependabot PRs. Deferred from build step 4 to build step 6, when the first lock files exist; until then Dependabot NuGet PRs may fail the locked restore.
- A one-command fix script restores lock files when CI flags a mismatch.

## Pillars affected

Security: tamper-checked, reproducible restores. Reliability: CI builds exactly what was tested.

## Sources

- owner, 2026-11-01
- https://github.com/dotnet/sdk/issues/38200, retrieved 2026-11-01
- https://github.com/Synertry/OpenTDBLookup/pull/25, retrieved 2026-11-01
