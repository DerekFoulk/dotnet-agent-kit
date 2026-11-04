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
    status: proposed
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: until the banned-API analyzer for pure assemblies (web profile, after v0.1)"
    scope: core
    paths: ["src/**"]
---

# Architecture

The defaults are Clean Architecture for web apps, and native MAUI with the MVVM Toolkit and Shell for mobile (ADR-0008). Architecture practice follows the Azure Well-Architected Framework (ADR-0016). Diagrams live as Mermaid in `docs/architecture/` and are updated in the same PR as the change they describe.

## Pending ratification

ARC-008 (pure business logic) came from an agent in one project. The brief recommends keeping it as an opt-in rule (brief §7). It stays `proposed` until you accept it.
