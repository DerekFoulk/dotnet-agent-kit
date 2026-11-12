---
topic: architecture
rules:
  - id: ARC-001
    statement: "Web apps use Clean Architecture in one deployable app; each distinct business area is a module with Domain, Application, Infrastructure, Presentation and Contracts projects, and Application code is grouped by feature; a project can deviate by ADR."
    why: "Compiler-enforced boundaries keep change local, and a well-bounded module can later become its own service."
    layer: owner
    status: accepted
    sources: ["ADR-0008"]
    enforcement: "ci: sample/tests/Bookmarks.Architecture.Tests (LayerTests, ArchUnitNET) fails when a layer depends outward; the module's project set and grouping by feature are advisory, checked by the reviewer agent"
    scope: core
    paths: ["src/**", "sample/**"]
  - id: ARC-002
    statement: "Modules talk to each other only through their Contracts projects."
    why: "It keeps modules independent and separable."
    layer: owner
    status: accepted
    sources: ["ADR-0008"]
    enforcement: "advisory: the sample has one module, so there's nothing to check yet; an ArchUnitNET test comes with the first app that has two"
    scope: core
    paths: ["src/**", "sample/**"]
  - id: ARC-003
    statement: "Shared libraries (Domain, Application, Contracts, API client, validation, UI-independent presentation logic) reference no UI or platform package."
    why: "Web and MAUI apps reuse the same libraries; a UI reference would break that."
    layer: owner
    status: accepted
    sources: ["ADR-0008"]
    enforcement: "ci: sample/tests/Bookmarks.Architecture.Tests (SharedLibraryTests) fails when Domain, Contracts or Application references an ASP.NET Core, EF Core, MAUI or WPF assembly"
    scope: core
    paths: ["src/**", "sample/**"]
  - id: ARC-004
    statement: "Microservices, Blazor Hybrid for MAUI, and a non-LTS .NET target each need an ADR."
    why: "Each is a deliberate exception to the defaults in ADR-0005 and ADR-0008."
    layer: owner
    status: accepted
    sources: ["ADR-0005", "ADR-0008"]
    enforcement: "advisory: an architecture choice; the reviewer agent checks for the ADR"
    scope: core
    paths: ["**"]
  - id: ARC-005
    statement: "Record significant technical decisions as ADRs in docs/adr from the template, with options, trade-offs, a recommendation and the pillars affected."
    why: "The Well-Architected Framework asks for decisions with context, trade-offs and rejected options."
    layer: owner
    status: accepted
    sources: ["ADR-0016"]
    enforcement: "ci: kit-checks.reusable.yml runs tools/Test-AdrSections.ps1"
    scope: core
    paths: ["docs/adr/**"]
  - id: ARC-006
    statement: "Plans cover the five Well-Architected pillars (reliability, security with a short threat model where data or sign-in is touched, cost, operational excellence including observability, performance), plus accessibility, data and docs."
    why: "Two plans were rejected for missing health checks and telemetry."
    layer: owner
    status: accepted
    sources: ["ADR-0016"]
    enforcement: "advisory: the plan-checklist skill lists the pillars and the reviewer agent checks plans; no tool can judge a plan"
    scope: core
    paths: ["**"]
  - id: ARC-007
    statement: "Proofs of concept live in spikes/ and are never merged into production code as-is."
    why: "A spike answers a question; production code is rewritten test-first."
    layer: owner
    status: accepted
    sources: ["ADR-0016"]
    enforcement: "advisory: spikes/ holds only write-ups so far, nothing code can reference; a CI path check comes when a spike keeps code"
    scope: core
    paths: ["spikes/**"]
  - id: ARC-008
    statement: "Assemblies marked pure (core business logic) use no hidden dependencies: no clock, randomness, file or network access except through injected abstractions."
    why: "Pure logic gives deterministic tests; opt-in per project."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    enforcement: "advisory: the banned-API analyzer now runs in every project (ADR-0043), but the ban list for pure assemblies (clock, randomness, file and network access) isn't written yet (web profile, after v0.1)"
    scope: core
    paths: ["src/**"]
  - id: ARC-010
    statement: "In MAUI and desktop apps, view models and all other logic live in UI-independent libraries (ARC-003); a UI project, one that sets UseMaui, UseWPF, UseWindowsForms or UseWinUI, holds only views, platform code and startup wiring, no other project references it, and the coverage gate exempts it."
    why: "No plain test project can load a UI project, and Linux CI can't build one; with the logic in libraries it's tested and covered like any other code, and the UI project has nothing left to cover."
    layer: owner
    status: proposed
    sources: ["ADR-0008", "ADR-0057", "https://learn.microsoft.com/dotnet/architecture/maui/mvvm, retrieved 2026-11-01"]
    enforcement: "ci: tools/Get-UiProject.ps1 fails when a project references a UI project (tools/tests/Get-UiProject.Tests.ps1), dotnet-ci.reusable.yml builds and tests every other project on Linux, and tools/Test-CoverageGate.ps1 exempts UI projects; that a UI project holds no logic is advisory, checked by the reviewer agent"
    scope: core
    paths: ["src/**", "**/*.csproj"]
  - id: ARC-011
    statement: "Desktop apps use .NET MAUI (Windows and Mac Catalyst), the same stack as mobile; WPF, Windows Forms or WinUI 3 need an ADR."
    why: "One UI stack across phone and desktop shares the most code and the kit's CI and rules; the others serve Windows alone."
    layer: owner
    status: proposed
    sources: ["ADR-0008", "ADR-0057"]
    enforcement: "advisory: an architecture choice; the reviewer agent checks for the ADR"
    scope: core
    paths: ["**/*.csproj"]
---

# Architecture

The defaults are Clean Architecture for web apps, and native MAUI with the MVVM Toolkit and Shell for mobile (ADR-0008). Architecture practice follows the Azure Well-Architected Framework (ADR-0016). Diagrams live as Mermaid in `docs/architecture/` and are updated in the same PR as the change they describe.

## MAUI and desktop apps

ADR-0057 sets how these are shaped and built.

- **Thin UI projects (ARC-010).** The UI project holds views (XAML and their code-behind), platform code and `MauiProgram`'s wiring. View models, commands, validation and everything else go in plain `net10.0` libraries, tested like any other. CommunityToolkit.Mvvm doesn't depend on a UI, so view models built with it live there too.
- **CI.** The shared .NET CI finds UI projects with `tools/Get-UiProject.ps1`. Linux builds and tests every other project through a solution filter. A `ui` job builds with zero warnings on Windows (the whole solution) and on macOS (all but the Windows-only UI projects), with the workloads restored at the workload set of the SDK in use (SUP-011). The required check waits for it. Tests stay on Linux, where Testcontainers' Linux containers work.
- **Lock files.** They're made on Windows, where a MAUI project targets every platform. macOS builds a subset, so it restores without locked mode, and `tools/Test-LockFileSubset.ps1` then fails unless each lock file matches the committed one for every framework it lists.
- **On your machine.** Install the MAUI workload at the same workload set CI uses: `dotnet workload install maui --version <the version dotnet --version prints>`. Visual Studio's installer manages its own workloads instead; either works for building.

## Pending ratification

ARC-010 and ARC-011 were added in auto mode (ADR-0035), so they stay `proposed` until you accept them. The coverage gate's exemption is in force once this change merges, which needs your yes, since it changes a CI check (AGENTS.md, "Working modes").
