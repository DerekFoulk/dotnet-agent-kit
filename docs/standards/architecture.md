---
topic: architecture
rules:
  - id: ARC-001
    statement: "Web apps use Clean Architecture in one deployable app; each distinct business area is a module with Domain, Application, Infrastructure, Presentation and Contracts projects, and Application code is grouped by feature; a project can deviate by ADR."
    why: "Compiler-enforced boundaries keep change local, and a well-bounded module can later become its own service."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0008"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: sample/tests/Bookmarks.Architecture.Tests (LayerTests, ArchUnitNET) fails when a layer depends outward"
      - kind: advisory
        in: [app]
        how: "until the app's Architecture.Tests carries the same test, following the sample"
      - kind: advisory
        in: [kit, app]
        how: "the module's project set and grouping by feature, checked by the reviewer agent"
    scope: core
    paths: ["src/**", "sample/**"]
  - id: ARC-002
    statement: "Modules talk to each other only through their Contracts projects."
    why: "It keeps modules independent and separable."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0008"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the sample has one module, so there's nothing to check yet; an ArchUnitNET test comes with the first app that has two"
    scope: core
    paths: ["src/**", "sample/**"]
  - id: ARC-003
    statement: "Shared libraries (Domain, Application, Contracts, API client, validation, UI-independent presentation logic) reference no UI or platform package."
    why: "Web and MAUI apps reuse the same libraries; a UI reference would break that."
    layer: owner
    basis: authority
    status: accepted
    sources: ["ADR-0008", "https://learn.microsoft.com/dotnet/architecture/maui/mvvm, retrieved 2026-11-12"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: sample/tests/Bookmarks.Architecture.Tests (SharedLibraryTests) fails when Domain, Contracts or Application references an ASP.NET Core, EF Core, MAUI or WPF assembly"
      - kind: advisory
        in: [app]
        how: "until the app's Architecture.Tests carries the same test, following the sample"
    scope: core
    paths: ["src/**", "sample/**"]
  - id: ARC-004
    statement: "Microservices, Blazor Hybrid for MAUI, and a non-LTS .NET target each need an ADR."
    why: "Each is a deliberate exception to the defaults in ADR-0005 and ADR-0008."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0005", "ADR-0008"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "an architecture choice; the reviewer agent checks for the ADR"
    scope: core
    paths: ["**"]
  - id: ARC-005
    statement: "Record significant technical decisions as ADRs in docs/adr from the template, with options, trade-offs, a recommendation and the pillars affected."
    why: "The Well-Architected Framework asks for decisions with context, trade-offs and rejected options."
    layer: owner
    basis: authority
    status: accepted
    sources: ["ADR-0016", "https://learn.microsoft.com/azure/well-architected/architect-role/fundamentals, retrieved 2026-11-12"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: kit-checks.reusable.yml runs tools/Test-AdrSections.ps1"
      - kind: gate
        in: [app]
        how: "ci: app-checks.reusable.yml runs tools/Test-AdrSections.ps1"
    scope: core
    paths: ["docs/adr/**"]
  - id: ARC-006
    statement: "Plans cover the five Well-Architected pillars (reliability, security with a short threat model where data or sign-in is touched, cost, operational excellence including observability, performance), plus accessibility, data and docs."
    why: "Two plans were rejected for missing health checks and telemetry."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0016"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the plan-checklist skill lists the pillars and the reviewer agent checks plans; no tool can judge a plan"
    scope: core
    paths: ["**"]
  - id: ARC-007
    statement: "Proofs of concept live in spikes/ and are never merged into production code as-is."
    why: "A spike answers a question; production code is rewritten test-first."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0016"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "spikes/ holds only write-ups so far, nothing code can reference; a CI path check comes when a spike keeps code"
    scope: core
    paths: ["spikes/**"]
  - id: ARC-008
    statement: "Assemblies marked pure (core business logic) use no hidden dependencies: no clock, randomness, file or network access except through injected abstractions."
    why: "Pure logic gives deterministic tests; opt-in per project."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the banned-API analyzer runs in every project (ADR-0043), but the ban list for pure assemblies (clock, randomness, file and network access) isn't written yet (web profile, after v0.1)"
    scope: core
    paths: ["src/**"]
  - id: ARC-009
    statement: "Give an app only the structure today's requirements need: a web app starts with one ARC-001 module and gets another only for a second distinct business area (its own language, data and rules), never one per entity or feature; a console tool, a standalone worker or a library is one project and its tests, its concerns kept apart by namespace, until code another app must share or a boundary the compiler must enforce needs a second project (ARC-010 settles MAUI and desktop apps); every project, each of a module's five included, is created with its first real type, never before; and inside a module, aggregates, value objects, domain events, CQRS, a mediator, a generic repository or an interface that inverts no dependency come only with the requirement the plan names for each."
    why: "Microsoft keeps DDD and CQRS patterns for complex domains and calls them over-engineering for simple services, and the Well-Architected Framework asks for every component to be justified by a requirement; an agent following ARC-001 to the letter can still build every layer and pattern for a tiny app (GAP-002)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["ADR-0052", "ADR-0008", "https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/ddd-oriented-microservice, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/eshoponcontainers-cqrs-ddd-microservice, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/well-architected/reliability/simplify, retrieved 2026-11-11"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: dotnet-ci.reusable.yml runs tools/Test-EmptyProjects.ps1, which fails on a C# project in the solution with no source of its own (C#, Razor or .proto files) or with the class library template's empty Class1 left in it"
      - kind: advisory
        in: [kit, app]
        how: "the number of modules and the patterns inside them: the plan-checklist skill asks, and the reviewer agent checks"
    scope: core
    paths: ["**"]
  - id: ARC-010
    statement: "In MAUI and desktop apps, view models and all other logic live in UI-independent libraries (ARC-003); a UI project, one that sets UseMaui, UseWPF, UseWindowsForms or UseWinUI, holds only views, platform code and startup wiring, no other project references it, and the coverage gate exempts it."
    why: "No plain test project can load a UI project, and Linux CI can't build one; with the logic in libraries it's tested and covered like any other code, and the UI project has nothing left to cover."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0008", "ADR-0059", "https://learn.microsoft.com/dotnet/architecture/maui/mvvm, retrieved 2026-11-01"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: tools/Get-UiProject.ps1 fails when a project references a UI project (tools/tests/Get-UiProject.Tests.ps1), dotnet-ci.reusable.yml builds and tests every other project on Linux, and tools/Test-CoverageGate.ps1 exempts UI projects"
      - kind: advisory
        in: [kit, app]
        how: "that a UI project holds no logic, checked by the reviewer agent"
    scope: core
    paths: ["src/**", "**/*.csproj"]
  - id: ARC-011
    statement: "Desktop apps use .NET MAUI (Windows and Mac Catalyst), the same stack as mobile; WPF, Windows Forms or WinUI 3 need an ADR."
    why: "One UI stack across phone and desktop shares the most code and the kit's CI and rules; the others serve Windows alone."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0008", "ADR-0059"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "an architecture choice; the reviewer agent checks for the ADR"
    scope: core
    paths: ["**/*.csproj"]
---

# Architecture

The defaults are Clean Architecture for web apps, and native MAUI with the MVVM Toolkit and Shell for mobile (ADR-0008). Architecture practice follows the Azure Well-Architected Framework (ADR-0016). Diagrams live as Mermaid in `docs/architecture/` and are updated in the same PR as the change they describe.

## How much structure (ARC-009)

ARC-001 sets the shape of a web app; ARC-009 sets how much of it to build, in four steps (ADR-0052):

1. **Modules.** A web app starts with one ARC-001 module. It gets a second only for a second distinct business area, one with its own language, data and rules (a bounded context, in domain-driven design's terms), never one per entity or feature.
2. **Projects outside ARC-001.** A console tool, a standalone worker or a library is one project and its tests (TST-003), with its concerns kept apart by namespace. It gets a second project only for code another app must share, or a boundary the compiler must enforce.
3. **No empty projects.** A project is created with its first real type, and that includes each of ARC-001's five module projects: ARC-009 reads them as a module's full shape, reached as each one's first type arrives, not a set to scaffold on day one. A one-module app with no other module to call it has no Contracts project yet (ARC-002). `tools/Test-EmptyProjects.ps1` fails CI on a C# project with no source of its own (C#, Razor or `.proto` files), and on one that keeps `dotnet new classlib`'s empty `Class1`.
4. **Patterns.** Inside a module, aggregates, value objects, domain events, CQRS, a mediator, a generic repository, or an interface that inverts no dependency (speculation, by CRF-004: see craft.md's SOLID notes) come only with the requirement the plan names for each. An interface that lets a test replace infrastructure does invert a dependency. A CRUD feature stays a simple endpoint, handler and data model.

MAUI and desktop apps keep ADR-0008's MVVM defaults, with the project structure below (ARC-010).

## MAUI and desktop apps

ADR-0059 sets how these are shaped and built.

- **Thin UI projects (ARC-010).** The UI project holds views (XAML and their code-behind), platform code and `MauiProgram`'s wiring. View models, commands, validation and everything else go in plain `net10.0` libraries, tested like any other. CommunityToolkit.Mvvm doesn't depend on a UI, so view models built with it live there too.
- **CI.** The shared .NET CI finds UI projects with `tools/Get-UiProject.ps1`. Linux builds and tests every other project through a solution filter. A `ui` job builds with zero warnings on Windows (the whole solution) and on macOS (all but the Windows-only UI projects), with the workloads restored at the workload set of the SDK in use (SUP-011). The required check waits for it. Tests stay on Linux, where Testcontainers' Linux containers work.
- **Lock files.** They're made on Windows, where a MAUI project targets every platform. macOS builds a subset, so it restores without locked mode, and `tools/Test-LockFileSubset.ps1` then fails unless each lock file matches the committed one for every framework it lists.
- **On your machine.** Install the MAUI workload at the same workload set CI uses: `dotnet workload install maui --version <the version dotnet --version prints>`. Visual Studio's installer manages its own workloads instead; either works for building.

## Pending ratification

ARC-010 and ARC-011 were added in auto mode (ADR-0035), so they stay `proposed` until you accept them. The coverage gate's exemption is in force once this change merges, which needs your yes, since it changes a CI check (AGENTS.md, "Working modes").
