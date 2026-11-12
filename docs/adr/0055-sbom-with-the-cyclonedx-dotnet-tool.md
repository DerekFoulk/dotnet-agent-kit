# ADR-0055: Every build writes a CycloneDX SBOM with the CycloneDX .NET tool

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

The quality scorecard's GAP-013 is "No SBOM is produced for an app's build." An SBOM (software bill of materials) lists every component a build ships: each package, its version and its licence. With one, when a package is found to be vulnerable, the question "which of our builds ship it?" has an answer. The Microsoft cloud security benchmark asks for one in "industry-standard formats (SPDX, CycloneDX)" (DS-2), and Microsoft's Secure Future Initiative counts the share of builds that write one.

Every app builds in the kit's shared workflow, `dotnet-ci.reusable.yml`, as the kit does. No app is deployed yet, so there's no published drop folder to describe (GAP-015). The kit's sample solution has projects, so the kit's own CI runs the step on every pull request.

This ADR was decided in auto mode (ADR-0035). Both tools below are free and open source.

## Options

### Option 1: The CycloneDX .NET tool (OWASP, Apache-2.0), run on the solution

`dotnet-CycloneDX` reads the package graph that the locked restore already wrote, for every project in the solution (it accepts `.slnx`). It leaves out test projects (`--exclude-test-projects`) and writes CycloneDX JSON. The shared workflow installs it for that run only, at the version pinned in the kit's `.config/dotnet-tools.json`, as it does Stryker.NET. Dependabot keeps that version current.

- **Trade-offs:** One step, with no build output needed. It describes the packages each shipped project resolves, including transitive ones. CycloneDX is an OWASP standard that GitHub's dependency submission and most scanners read. It doesn't hash the built files; that belongs with build provenance and a deployment pipeline (GAP-015).
- **Reversibility:** Easy. Remove the three steps and the manifest entry.
- **Risk:** Low. A tool failure fails the build, which is visible and fixed by a version change.

### Option 2: Microsoft's SBOM tool (`Microsoft.Sbom.DotNetTool`, MIT), SPDX 2.2

Microsoft's own generator, named in the benchmark's example and the CISA maturity-model guidance on Microsoft Learn. It scans a build drop folder (`-b`) and the source tree (`-bc`). It needs a package name, a version and a supplier name on every run.

- **Trade-offs:** It hashes the files in the drop, which suits a release. But there's no drop until an app is published, so today the kit would have to publish every project first just to describe it. It scans the whole source tree, test projects included, unless told otherwise. The tool targets .NET 8 only, so it needs that runtime beside the SDK the app pins.
- **Reversibility:** Easy.
- **Risk:** Medium: more inputs to keep right in a shared workflow that every app runs.

### Option 3: GitHub's dependency graph export

GitHub can export an SPDX SBOM of a repo's dependency graph, from the Insights tab or its REST API.

- **Trade-offs:** No workflow change. But it describes the repo's manifests, not a build, and isn't kept with the run that built the code.
- **Reversibility:** Easy.
- **Risk:** Medium: it isn't tied to what was built, which is what GAP-013 asks for.

## Recommendation

Option 1: it describes exactly the projects a build ships, from the restore the build already did, in one step with a pinned, Dependabot-managed tool. Option 2 fits a release drop better, and the deployment pipeline (GAP-015) can add it there if a consumer asks for SPDX.

## Decision

Proposed (auto mode, ADR-0035), with SUP-009; the owner accepts or changes it.

## Consequences

- New rule SUP-009 (proposed) in `docs/standards/supply-chain.md`. GAP-013 is closed.
- `dotnet-ci.reusable.yml` installs CycloneDX at the version the kit's tool manifest pins, writes `sbom.cdx.json` and uploads it as the `sbom` artifact, which GitHub keeps for the repo's artifact retention period (90 days by default). It runs only once the solution has projects, like the other .NET steps. An app gets it with its next kit pin, with no change of its own.
- `.config/dotnet-tools.json` pins `cyclonedx`, so `dotnet tool restore` installs it locally too.
- `tools/tests/SharedCi.Tests.ps1` checks the steps.

## Pillars affected

- **Security:** every build records what it ships, so a newly disclosed vulnerability can be traced to the builds that contain it.
- **Operational Excellence:** the SBOM is kept with the run that built it, from one shared, versioned workflow.
- **Cost Optimization:** free; the tool is open source and adds seconds to a free Linux job on a public repo.
- **Reliability and Performance Efficiency:** not affected.

## Sources

- https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-devops-security, DS-2, retrieved 2026-11-11
- https://learn.microsoft.com/security/zero-trust/sfi/protect-software-supply-chain, retrieved 2026-11-11
- https://learn.microsoft.com/security/zero-trust/cisa-zero-trust-maturity-model-apps, retrieved 2026-11-11
- https://github.com/CycloneDX/cyclonedx-dotnet, retrieved 2026-11-11
- https://www.nuget.org/packages/CycloneDX/6.3.1 (Apache-2.0, published 2026-10-12), retrieved 2026-11-11
- https://github.com/microsoft/sbom-tool, retrieved 2026-11-11
