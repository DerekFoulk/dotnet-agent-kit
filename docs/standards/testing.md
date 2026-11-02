---
topic: testing
rules:
  - id: TST-001
    statement: "Write the test first: commit it failing on an assertion (red), then commit the change that makes the full suite pass (green), then refactor on green."
    why: "The owner is \"a true believer in TDD\"; a test seen failing for the right reason proves it tests something."
    layer: owner
    status: accepted
    sources: ["owner, 2026-10-26", "ADR-0018"]
    enforcement: "advisory: until tools/Test-RedGreenOrder.ps1 runs in CI (build step 4)"
    scope: core
    paths: ["**"]
  - id: TST-002
    statement: "Every plan includes a test list; turn one item at a time into a failing test, never the whole list up front."
    why: "Canon TDD: converting the whole list first locks in early design choices that later tests show were wrong."
    layer: owner
    status: accepted
    sources: ["ADR-0018"]
    enforcement: "advisory: the start-work and plan-checklist skills require a test list and the reviewer agent checks for it; no tool can judge a plan"
    scope: core
    paths: ["**"]
  - id: TST-003
    statement: "Each part of an app gets the test kinds in the brief's test matrix (unit, integration, functional, UI, architecture, contract, mutation), in one test project per production project plus the shared IntegrationTests, FunctionalTests, E2E.Tests and Architecture.Tests projects."
    why: "The owner wants complete coverage of all test types, to the extent that is best practice."
    layer: owner
    status: accepted
    sources: ["owner, 2026-10-25", "owner, 2026-10-26"]
    enforcement: "advisory: until coverage gates and architecture tests run on the sample solution (build steps 4 and 6)"
    scope: core
    paths: ["**/*.csproj", "**/*Tests*/**"]
  - id: TST-004
    statement: "Coverage gates: 100% line coverage for pure domain assemblies, 95% for application assemblies, 90% overall; mutation score 85% (nightly)."
    why: "Thresholds approved in one project's plan; proposed here as kit defaults."
    layer: owner
    status: proposed
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: until the coverage gate (build step 4) and nightly mutation run (after v0.1)"
    scope: core
    paths: ["**/*Tests*/**"]
  - id: TST-005
    statement: "Use the kit test toolset (xUnit v3, Moq, FluentAssertions 8, Bogus, bUnit, Playwright, Testcontainers, ArchUnitNET, FsCheck, Stryker and the ADR-0003 additions); a different tool needs an ADR."
    why: "One toolset the owner chose; FluentAssertions is swapped for AwesomeAssertions in commercial repos (ADR-0004)."
    layer: owner
    status: accepted
    sources: ["ADR-0003"]
    enforcement: "advisory: central package management keeps versions in one reviewed file; a package allowlist check comes later"
    scope: core
    paths: ["Directory.Packages.props", "**/*.csproj"]
  - id: TST-006
    statement: "Every kit script and check has Pester tests, written first."
    why: "Scripts are code; the owner's test-first rule applies to them too."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "ADR-0011"]
    enforcement: "advisory: until CI runs Pester and the red-green order check (build step 4)"
    scope: core
    paths: ["tools/**"]
---

# Testing

Test-first at every level (ADR-0018). The test matrix in brief §6.7 sets which kinds of test each part of an app gets. "Acceptance test" names a purpose, not a kind of test: a test written from a requirement, usually at the functional or UI level. It's tagged with its requirement rather than given its own folder.

## Pending ratification

TST-004's thresholds were approved in one project's plan. They stay `proposed` until you accept them as kit defaults.
