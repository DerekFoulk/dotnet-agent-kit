# ADR-0066: Restores require nuget.org's repository signature

- **Status:** Accepted
- **Date:** 2026-11-13

## Context

SUP-003 lets packages come only from nuget.org, and lock files hold each package's hash (SUP-001). Neither checks who produced a package. nuget.org adds a repository signature to every package it serves, and NuGet can require a signature from a trusted signer before it extracts a package (`signatureValidationMode` set to `require`, with a `trustedSigners` section in `nuget.config`). Microsoft's NuGet supply-chain guidance recommends a trust policy. The rules audit added a rule for it (owner, 2026-11-12: "Yes, accept them").

nuget.org announces its repository certificates in its service index, and replaces them when they expire.

## Options

### Option 1: Require nuget.org's repository signature

`nuget.config` sets `signatureValidationMode` to `require` and trusts nuget.org's repository certificates, written by `dotnet nuget trust source nuget.org`, which reads them from the service index.

- **Trade-offs:** Every package must come from nuget.org's signing pipeline, unchanged; a tampered or foreign package fails with NU3004. Any package nuget.org serves is accepted, whoever published it. When nuget.org rotates its certificate, restores of packages signed with the new one fail until `dotnet nuget trust sync nuget.org` updates the list.
- **Reversibility:** Easy: remove the setting and the section.
- **Risk:** Low to medium: a rotation breaks restores in the kit and every app at once, until someone syncs.

### Option 2: Also restrict owners

Add `<owners>` to the repository signer, such as `microsoft;aspnet;nuget`.

- **Trade-offs:** Narrower trust, but every third-party package the kit uses (MinVer, FluentAssertions, ArchUnitNET and others) needs its owner listed, and a new dependency fails until its owner is added.
- **Reversibility:** Easy.
- **Risk:** Medium: constant upkeep, and a list nobody reads soon stops meaning much.

### Option 3: No policy

Keep source mapping and lock files only.

- **Trade-offs:** Nothing to maintain; no signature check at all.
- **Reversibility:** Not applicable.
- **Risk:** The gap SUP-012 exists to close.

## Recommendation

Option 1: it closes the gap with one documented setting and NuGet's own command, without a list to maintain.

## Decision

Accepted as recommended, as part of the rules audit (owner, 2026-11-12).

## Consequences

- SUP-012 (accepted). `nuget.config` in the kit, and in every app through the export and the kit sync, requires a trusted signature.
- NuGet merges `trustedSigners` from every config above the repo, the user's and the machine's included, so the section starts with `<clear />`: only nuget.org's repository is trusted in the repo, whatever a developer's own config trusts (Copilot's review of PR #69).
- `tools/tests/BuildConfig.Tests.ps1` restores a hand-built unsigned package and expects NU3004, and restores nuget.org's packages successfully, each in an empty global packages folder of its own: NuGet checks a signature when it extracts a package, so a copy already on the machine would skip the check. It also checks, with `dotnet nuget trust list`, that a signer trusted in a config above the repo isn't trusted in it.
- A package already in a machine's global packages folder isn't checked again; CI's fresh runners extract every package.
- **macOS is an exception** (Copilot's review of PR #69). .NET verifies signatures during a restore on Windows always, and on Linux by default from the .NET 8 SDK. On macOS it doesn't: Microsoft says the feature isn't supported there and to leave it disabled, so the kit doesn't set `DOTNET_NUGET_SIGNATURE_VERIFICATION` to turn it on. In CI the macOS restore is still held to the packages verified elsewhere: `Test-LockFileSubset.ps1` requires its lock files, hashes included, to match the committed ones, which the Windows and Linux restores of the same commit verified. A developer's own Mac gets the lock files' hash check, not the signature check. A test keeps any workflow from turning verification off where it runs.
- **Not yet handled:** nothing notices a certificate rotation before a restore fails. Scorecard GAP-038 tracks a scheduled check that compares `nuget.config` with nuget.org's service index.

## Pillars affected

Security: a package must come unchanged from nuget.org's signing pipeline. Reliability: a certificate rotation can stop restores until the list is synced (GAP-038).

## Sources

- owner, 2026-11-12
- https://learn.microsoft.com/nuget/consume-packages/installing-signed-packages, retrieved 2026-11-13
- https://learn.microsoft.com/nuget/reference/nuget-config-file#trustedsigners-section, retrieved 2026-11-13
- https://learn.microsoft.com/nuget/reference/cli-reference/cli-ref-trusted-signers, retrieved 2026-11-13
- https://learn.microsoft.com/nuget/concepts/security-best-practices, retrieved 2026-11-12
- https://learn.microsoft.com/dotnet/core/tools/nuget-signed-package-verification, retrieved 2026-11-13
