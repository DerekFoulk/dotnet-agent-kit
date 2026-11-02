# ADR-0025: Pin the SDK with rollForward latestPatch

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

`global.json` pins the .NET SDK, and its `rollForward` policy decides which installed SDKs may be used instead. The owner's current repo uses `latestFeature`, which lets machines pick different SDK feature bands (for example 10.0.1xx on one machine and 10.0.4xx on another). That is a direct cause of the lock-file churn in ADR-0020.

## Options

### Option 1: `rollForward: latestPatch`, with CI and Dependabot moving the pin

- **Trade-offs:** Every machine and CI use the same feature band; a newer patch in that band is allowed. Moving to a new feature band is a deliberate PR.
- **Reversibility:** Easy.
- **Risk:** Low. A machine without that band gets a clear error, and `tools/Initialize-DevMachine.ps1` installs the pinned version.

### Option 2: `rollForward: latestFeature`

- **Trade-offs:** Fewer installs; machines can build with different feature bands, which changes SDK-implicit packages.
- **Reversibility:** Easy.
- **Risk:** Medium. Lock-file churn and "works on my machine" builds.

### Option 3: `rollForward: disable`

- **Trade-offs:** Exactly one SDK everywhere; every security patch needs a pin change before anyone can build with it.
- **Reversibility:** Easy.
- **Risk:** Medium. Blocks patches until the pin moves.

## Recommendation

Option 1: one feature band everywhere, security patches still allowed.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- `global.json` pins `10.0.403` with `latestPatch` and `allowPrerelease: false` (since build step 1).
- `tools/Initialize-DevMachine.ps1` checks the pin the same way the SDK does and installs the exact pinned version.
- Dependabot moves the pin (build step 4).

## Pillars affected

Reliability: reproducible builds across machines. Security: patches in the band are still picked up.

## Sources

- owner, 2026-11-01
- https://learn.microsoft.com/dotnet/core/tools/global-json, retrieved 2026-11-01
- https://github.com/dotnet/sdk/issues/38200, retrieved 2026-11-01
