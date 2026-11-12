# ADR-0055: Every build writes a CycloneDX SBOM with the CycloneDX .NET tool

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

The quality scorecard's GAP-013 is "No SBOM is produced for an app's build." An SBOM (software bill of materials) lists every component a build ships: each package, its version and its licence. With one, when a package is found to be vulnerable, the question "which of our builds ship it?" has an answer. The Microsoft cloud security benchmark asks for one in "industry-standard formats (SPDX, CycloneDX)" (DS-2), and Microsoft's Secure Future Initiative counts the share of builds that write one.

Every app builds in the kit's shared workflow, `dotnet-ci.reusable.yml`, as the kit does. No app is deployed yet, so there's no published drop folder to describe (GAP-015). The kit's sample solution has projects, so the kit's own CI runs the step on every pull request.

This ADR was decided in auto mode (ADR-0035). Both tools below are free and open source.

## Options

### Option 1: The CycloneDX .NET tool (OWASP, Apache-2.0), run on the solution

`dotnet-CycloneDX` reads the package graph that the locked restore already wrote, for each project it's given, and writes CycloneDX JSON. It accepts a solution or a solution filter (`.slnf`). Its own `--exclude-test-projects` reads only each project file's XML, so it misses a test project marked in a `Directory.Build.props`, as the kit's sample and every app's tests are. So the kit's `New-ShippedSolutionFilter.ps1` asks MSBuild for each project's `IsTestProject` and writes a filter of the rest, and the tool runs on that. The shared workflow installs it for that run only, at the version pinned in the kit's `.config/dotnet-tools.json`, as it does Stryker.NET. Dependabot keeps that version current.

- **Trade-offs:** No build output needed: one workflow step, with the kit's filter script. It describes the packages each shipped project resolves, including transitive ones; build-only packages, such as MinVer, appear with scope `excluded`. CycloneDX is an OWASP standard, one of the two formats the benchmark names, and widely read by vulnerability scanners such as OWASP Dependency-Track. It doesn't hash the built files; that belongs with build provenance and a deployment pipeline (GAP-015).
- **Reversibility:** Easy. Remove the three steps, the manifest entry, and `tools/New-ShippedSolutionFilter.ps1` with its tests.
- **Risk:** Low. A tool failure fails the build, which is visible and fixed by a version change.

### Option 2: Microsoft's SBOM tool (`Microsoft.Sbom.DotNetTool`, MIT), SPDX

Microsoft's own generator, named in the benchmark's example and the CISA maturity-model guidance on Microsoft Learn. It scans a build drop folder (`-b`) and the source tree (`-bc`). It writes SPDX 2.2 by default, or 3.0, and needs a package name, version, supplier and namespace base URI on every run.

- **Trade-offs:** It hashes the files in the drop, which suits a release. But there's no drop until an app is published, so today the kit would have to publish every project first just to describe it. It would need the same test-project filtering. The tool targets .NET 8 only, so it needs that runtime beside the SDK the app pins.
- **Reversibility:** Easy.
- **Risk:** Medium: more inputs to keep right in a shared workflow that every app runs.

### Option 3: GitHub's dependency graph export

GitHub can export an SPDX SBOM of a repo's dependency graph, from the Insights tab or its REST API.

- **Trade-offs:** No workflow change. But it describes the repo's manifests, not a build, and isn't kept with the run that built the code.
- **Reversibility:** Easy.
- **Risk:** Medium: it isn't tied to what was built, which is what GAP-013 asks for.

## Recommendation

Option 1: it describes exactly the projects a build ships, from the restore the build already did, with a pinned, Dependabot-managed tool. Option 2 fits a release drop better, and the deployment pipeline (GAP-015) can add it there if a consumer asks for SPDX.

## Decision

Proposed (auto mode, ADR-0035), with SUP-009; the owner accepts or changes it.

## Consequences

- New rule SUP-009 (proposed) in `docs/standards/supply-chain.md`. GAP-013 is closed.
- `tools/New-ShippedSolutionFilter.ps1`, with Pester tests, writes the filter of shipped projects. It runs from the kit's copy (the `kit-tools` action), so an app needs none.
- `dotnet-ci.reusable.yml` installs CycloneDX at the version the kit's tool manifest pins, writes `sbom.cdx.json` and uploads it as the `sbom` artifact, which GitHub keeps for the repo's artifact retention period (90 days by default). It runs only once the solution has projects, like the other .NET steps. In an app with MAUI or desktop projects, the Windows leg of the `ui` job writes it instead, with the same steps (ADR-0059). An app gets it with its next kit pin, with no change of its own.
- `.config/dotnet-tools.json` pins `cyclonedx`, so `dotnet tool restore` installs it locally too.
- `tools/tests/SharedCi.Tests.ps1` checks the steps.
- Amended by ADR-0062 (2026-11-12): benchmarks projects (names ending in `.Benchmarks`) ship nothing, so the filter leaves them out too.

## Pillars affected

- **Security:** every build records what it ships, so a newly disclosed vulnerability can be traced to the builds that contain it, while the artifact is kept (90 days by default). A release keeping its SBOM for good belongs with the deployment pipeline (GAP-015).
- **Operational Excellence:** the SBOM is kept with the run that built it, from one shared, versioned workflow.
- **Cost Optimization:** free; the tool is open source and adds seconds to a free Linux job on a public repo.
- **Reliability and Performance Efficiency:** not affected.

## Sources

- https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-devops-security, DS-2, retrieved 2026-11-11
- https://learn.microsoft.com/security/zero-trust/sfi/protect-software-supply-chain, retrieved 2026-11-11
- https://learn.microsoft.com/security/zero-trust/cisa-zero-trust-maturity-model-apps, retrieved 2026-11-11
- https://github.com/CycloneDX/cyclonedx-dotnet, retrieved 2026-11-11
- https://www.nuget.org/packages/CycloneDX/6.3.1 (Apache-2.0, published 2026-10-12), retrieved 2026-11-11
- https://github.com/CycloneDX/cyclonedx-dotnet/blob/v6.3.1/docs/dev-and-test-dependencies.md (test projects are recognised from the project XML only), retrieved 2026-11-11
- https://github.com/microsoft/sbom-tool, retrieved 2026-11-11
- https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization, retrieved 2026-11-11
