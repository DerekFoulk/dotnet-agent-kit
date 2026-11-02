# ADR-0008: Clean Architecture; native MAUI with the MVVM Toolkit and Shell

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner's projects converge on an ASP.NET Core API with a Blazor Web App, and some plan native mobile apps with .NET MAUI. The owner treats every project as if an enterprise team builds it, and wants maximum code reuse across apps. Native MAUI with MVVM is his stated preference over Blazor Hybrid (owner, 2026-11-01).

## Options

### Option 1: Clean Architecture in one deployable app, split into modules by business area

- **Trade-offs:** Domain, Application, Infrastructure, Presentation and Contracts projects per module; the compiler and architecture tests enforce the direction of dependencies; Application code is grouped by feature. More projects than a single-project app.
- **Reversibility:** Moderate. A well-bounded module can later become its own service.
- **Risk:** Low. Microsoft's architecture guide recommends it for non-trivial monolithic ASP.NET Core apps.

### Option 2: Microservices from the start

- **Trade-offs:** Independent deployment and scaling; much more operational cost and distributed-system failure modes, for teams and scale no current project has.
- **Reversibility:** Hard. Merging services back is costly.
- **Risk:** High. A scaling tool, not a quality upgrade.

### Option 3: Layer-by-type folders in a single project

- **Trade-offs:** Fewest projects; dependency rules can't be compiler-enforced, and one use case spreads across many folders.
- **Reversibility:** Moderate.
- **Risk:** Medium. Boundaries erode without enforcement.

For MAUI, Prism 9 was also considered: free under its Community License, with richer navigation and dialogs, but it replaces Shell's navigation, adds a framework dependency and a license condition, and its extras are covered by Shell, the Toolkit's messenger and plain dependency injection.

## Recommendation

Option 1, with native MAUI using CommunityToolkit.Mvvm and Shell behind a small navigation interface.

## Decision

Accepted as recommended, after discussion (owner, 2026-11-01).

## Consequences

- Web: Clean Architecture modules in one deployable app; modules talk only through Contracts; feature folders inside Application.
- MAUI: native UI in C#/XAML; MVVM with CommunityToolkit.Mvvm; Shell for URI navigation and deep links. Blazor Hybrid only by ADR.
- Domain, Application, Contracts, the generated API client, validation rules and UI-independent presentation logic are shared libraries; architecture tests stop them referencing any UI or platform package.
- Microservices only by ADR.

## Pillars affected

Reliability and Operational Excellence: enforced boundaries keep change local. Performance Efficiency: one deployable avoids network hops between modules.

## Sources

- owner, 2026-11-01
- https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures, retrieved 2026-11-01
- https://learn.microsoft.com/dotnet/architecture/maui/mvvm, retrieved 2026-11-01
- https://www.nuget.org/packages/Prism.Core/9.0.537, retrieved 2026-11-01
