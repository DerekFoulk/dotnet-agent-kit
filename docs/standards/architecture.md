---
topic: architecture
rules:
  - id: ARC-001
    statement: "Web apps use Clean Architecture in one deployable app; each distinct business area is a module with Domain, Application, Infrastructure, Presentation and Contracts projects, and Application code is grouped by feature; a project can deviate by ADR."
    why: "Compiler-enforced boundaries keep change local, and a well-bounded module can later become its own service. Microsoft's reference application, eShopOnWeb, uses the Clean Architecture approach in three projects (Application Core, Infrastructure and UI); the five projects per module, the modules and the grouping by feature are the kit's refinement (ADR-0008). ARC-016 holds what Microsoft says about Clean Architecture itself."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0008", "https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures"
        retrieved: "2026-11-17"
        text: "The eShopOnWeb reference application uses the Clean Architecture approach in organizing its code into projects."
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared architecture tests (tools/AppTests/Architecture), which tests/Directory.Build.props compiles into every *.Architecture.Tests project, the sample's and an app's, which names its assemblies by layer in its own part of AppLayers (ADR-0081): LayerTests fails when a domain, contracts, application or infrastructure assembly references one in a layer outside it; an app without that project isn't checked until TST-003's check (GAP-027)"
      - kind: advisory
        in: [kit, app]
        how: "the module's project set and grouping by feature, checked by code review"
    projectTypes: [web-api, blazor, razor-pages-mvc]
    paths: ["src/**", "sample/**"]
  - id: ARC-002
    statement: "Modules talk to each other only through their Contracts projects; a module never reads or writes another module's tables, and an app never shares its database with another app."
    why: "It keeps modules independent and separable. Microsoft's microservices guidance says the data each microservice owns is private to it and should only be accessed through its API endpoints or by messaging, so that schema changes don't need coordinating across services; the kit applies that to modules (rules audit, owner 2026-11-12)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0008", "owner, 2026-11-12", "https://learn.microsoft.com/dotnet/architecture/microservices/architect-microservice-container-applications/data-sovereignty-per-microservice, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/architecture/microservices/architect-microservice-container-applications/data-sovereignty-per-microservice"
        retrieved: "2026-11-17"
        text: "Even when using ACID transactions within a microservice or Bounded Context, it is crucial to consider that the data owned by each microservice is private to that microservice and should only be accessed either synchronously through its API endpoints(REST, gRPC, SOAP, etc) or asynchronously via messaging(AMQP or similar)."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the sample has one module, so there's nothing to check yet; an ArchUnitNET test comes with the first app that has two, and code review checks that no module's Infrastructure maps another module's tables and that an app's connection strings name a database of its own"
    projectTypes: [web-api, blazor, razor-pages-mvc]
    paths: ["src/**", "sample/**"]
  - id: ARC-003
    statement: "Shared libraries (Domain, Application, Contracts, API client, validation, UI-independent presentation logic) reference no UI or platform package."
    why: "Web and MAUI apps reuse the same libraries; a UI reference would break that. No Microsoft page says it in these words, so it is the kit's own (ADR-0008); ARC-017 holds what Microsoft's MVVM page says about view models and views."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0008"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: the kit's shared architecture tests (tools/AppTests/Architecture), which tests/Directory.Build.props compiles into every *.Architecture.Tests project, the sample's and an app's, which names its assemblies by layer in its own part of AppLayers (ADR-0081): SharedLibraryTests fails when a domain, contracts or application assembly references an ASP.NET Core, EF Core, MAUI or WPF assembly; an app without that project isn't checked until TST-003's check (GAP-027)"
    projectTypes: [all]
    paths: ["src/**", "sample/**"]
  - id: ARC-004
    statement: "Microservices, Blazor Hybrid for MAUI, and a non-LTS .NET target each need an ADR."
    why: "Each is a deliberate exception to the defaults in ADR-0005 and ADR-0008; Well-Architected says microservices aren't the best option for every application because they can introduce complexity, overhead, and dependency issues."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0005", "ADR-0008", "https://learn.microsoft.com/azure/well-architected/reliability/simplify, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/well-architected/reliability/simplify"
        retrieved: "2026-11-17"
        text: "For example, microservices aren't the best option for every application because they can introduce complexity, overhead, and dependency issues."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "an architecture choice; code review checks for the ADR"
    projectTypes: [all]
    paths: ["**"]
  - id: ARC-005
    statement: "Record significant technical decisions as ADRs in docs/adr from the template, with options, trade-offs, a recommendation and the pillars affected."
    why: "The Well-Architected Framework asks for decisions with their context, tradeoffs and rejected options (ARC-015); the template, the options, the recommendation and the pillars affected are the kit's own (ADR-0016), and Test-AdrSections checks the sections."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0016"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: kit-checks.reusable.yml runs tools/Test-AdrSections.ps1"
      - kind: gate
        in: [app]
        how: "ci: app-checks.reusable.yml runs tools/Test-AdrSections.ps1"
    projectTypes: [all]
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
        how: "the plan-checklist skill lists the pillars, and start-work's plan review holds each plan against it before any code; no tool can judge a plan"
    projectTypes: [all]
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
    projectTypes: [all]
    paths: ["spikes/**"]
  - id: ARC-008
    statement: "No code reads the clock directly: the time comes from an injected TimeProvider, and TimeProvider.System appears only where the app registers it, or where code must agree with a clock it can't inject, such as a test token the app checks against the system clock. Assemblies marked pure (core business logic, such as a module's Domain project, marked by setting the PureAssembly property to true in its .csproj) also use no randomness, file, network, environment or process access except through values, streams, readers and writers their callers pass in, or abstractions of their own that are injected (never an HttpClient, even one passed in), and BannedSymbols.Pure.txt lists the APIs they may not call."
    why: "Pure logic gives deterministic tests; opt-in per project. The clock is read everywhere, so it's injected everywhere: Microsoft's world-ready apps page says you should use TimeProvider or a similar type when retrieving the time (ARC-018), and the sample does: its one test helper that read DateTime.UtcNow reads TimeProvider.System, the clock the API checks a token's lifetime against (.NET best-practices pass, owner 2026-11-16: \"Yes, accept them\"). The environment and other processes are outside state the same way, so the pure list bans them too, and the mark is a property Directory.Build.props reads (ADR-0080, GAP-039)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09", "owner, 2026-11-16", "ADR-0080", "https://learn.microsoft.com/dotnet/core/extensions/best-practices-for-developing-world-ready-apps, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/datetime/choosing-between-datetime, retrieved 2026-11-15", "https://learn.microsoft.com/visualstudio/msbuild/build-process-overview#evaluation-phase, retrieved 2026-11-16"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/best-practices-for-developing-world-ready-apps"
        retrieved: "2026-11-17"
        text: "You should also use TimeProvider or a similar type when retrieving the time."
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: BannedSymbols.txt bans DateTime.Now, UtcNow and Today and DateTimeOffset.Now and UtcNow in every project (RS0030), and the compiler rejects the obsolete TimeZone (CS0618, an error under STY-004); in a project that sets PureAssembly, Directory.Build.props adds BannedSymbols.Pure.txt, which bans randomness (Random, RandomNumberGenerator, Guid.NewGuid and CreateVersion7), file access (File, Directory, FileStream, path-opening stream constructors, zip and tar files, folder listings, an assembly's own location and the rest), network access (HttpClient, Socket, Dns and the rest), environment variables, the console, Stopwatch, the local time zone and the conversions that read it, pipes and processes (RS0030); tools/tests/BuildConfig.Tests.ps1 has a failing fixture row for each clock ban and for each pure family, rows showing what a pure assembly keeps (Path's string work, a stream passed in, Environment.NewLine), a clean fixture for an unmarked project, a check that every pure ID resolves, and a test that the sample's Domain project gets the pure list"
      - kind: advisory
        in: [kit, app]
        how: "code review checks what the bans can't see: TimeProvider.System outside the places the statement allows, Stopwatch or Environment.TickCount64 used as a clock outside a pure assembly, Task.Delay or a Timer with no TimeProvider where a test should control the wait, a project of core business logic that isn't marked pure, and, in a pure assembly, a path or URL reached through a general-purpose overload the list can't ban, such as XDocument.Load(string), or the machine's time zone reached the same way, such as TimeZoneInfo.ConvertTime(DateTime, TimeZoneInfo) or a DateTimeOffset made from a local DateTime"
    projectTypes: [all]
    paths: ["**/*.cs", "**/*.csproj", "BannedSymbols.txt", "BannedSymbols.Pure.txt"]
  - id: ARC-009
    statement: "Give an app only the structure today's requirements need: a web app starts with one ARC-001 module and gets another only for a second distinct business area (its own language, data and rules), never one per entity or feature; a console tool, a standalone worker or a library is one project and its tests, its concerns kept apart by namespace, until code another app must share or a boundary the compiler must enforce needs a second project (ARC-010 settles MAUI and desktop apps); every project, each of a module's five included, is created with its first real type, never before; and inside a module, aggregates, value objects, domain events, CQRS, a mediator, a generic repository or an interface that inverts no dependency come only with the requirement the plan names for each."
    why: "Microsoft's pages say not to use CQRS and DDD patterns everywhere and to justify every design decision with a business requirement (ARC-019); the sizes the kit gives, down to when a module or a project may exist, are its own (ADR-0052). An agent following ARC-001 to the letter can still build every layer and pattern for a tiny app (GAP-002)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0052", "ADR-0008"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: dotnet-ci.reusable.yml runs tools/Test-EmptyProjects.ps1, which fails on a C# project in the solution with no source of its own (C#, Razor or .proto files) or with the class library template's empty Class1 left in it"
      - kind: advisory
        in: [kit, app]
        how: "the number of modules and the patterns inside them: the plan-checklist skill asks, and code review checks"
    projectTypes: [all]
    paths: ["**"]
  - id: ARC-010
    statement: "In MAUI and desktop apps, view models and all other logic live in UI-independent libraries (ARC-003); a UI project, one that sets UseMaui, UseWPF, UseWindowsForms or UseWinUI, holds only views, platform code and startup wiring, no other project references it, and the coverage gate exempts it."
    why: "No plain test project can load a UI project, and Linux CI can't build one; with the logic in libraries it's tested and covered like any other code, and the UI project has nothing left to cover."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0008", "ADR-0059", "https://learn.microsoft.com/dotnet/architecture/maui/mvvm, retrieved 2026-11-17"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: tools/Get-UiProject.ps1 fails when a project references a UI project (tools/tests/Get-UiProject.Tests.ps1), dotnet-ci.reusable.yml builds and tests every other project on Linux, and tools/Test-CoverageGate.ps1 exempts UI projects"
      - kind: advisory
        in: [kit, app]
        how: "that a UI project holds no logic, checked by code review"
    projectTypes: [maui, blazor-hybrid, winui3, wpf, winforms]
    paths: ["src/**", "**/*.csproj"]
  - id: ARC-011
    statement: "A new general-purpose Windows desktop app is recommended to use WinUI 3, the native UI framework delivered with the Windows App SDK; a team expecting to target several platforms should start with .NET MAUI (Microsoft names React Native for Desktop beside it), which uses WinUI 3 when running on Windows."
    why: "The UI framework is the hardest choice to undo in a desktop app: Microsoft says a WinUI 3 app can't later add .NET MAUI for other platforms. The kit says \"WinUI 3\", never just \"WinUI\" (owner, 2026-11-17), because WinUI 2 is a different library, for UWP apps."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/get-started/windows-developer-faq, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/maui/what-is-maui, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/get-started/windows-developer-faq"
        retrieved: "2026-11-17"
        text: "If you're building a new general-purpose Windows desktop app, we recommend using WinUI 3."
      - source: "https://learn.microsoft.com/windows/apps/get-started/windows-developer-faq"
        retrieved: "2026-11-17"
        text: "WinUI 3 is the native UI framework delivered with the Windows App SDK."
      - source: "https://learn.microsoft.com/windows/apps/get-started/windows-developer-faq"
        retrieved: "2026-11-17"
        text: "Although .NET MAUI uses WinUI 3 when running on Windows, teams expecting to target multiple platforms should start with .NET MAUI or React Native for Desktop."
      - source: "https://learn.microsoft.com/dotnet/maui/what-is-maui"
        retrieved: "2026-11-17"
        text: "Windows apps built using .NET MAUI use Windows UI 3 (WinUI 3) library to create native apps that target the Windows desktop."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "an architecture choice in the plan; code review checks the framework against the app's platforms"
    projectTypes: [maui, blazor-hybrid, winui3, wpf, winforms]
    paths: ["**/*.csproj"]
  - id: ARC-014
    statement: "A new desktop app uses the framework ARC-011 names for its platforms (WinUI 3 for a Windows desktop app, .NET MAUI for several platforms); a new WPF or Windows Forms app needs an ADR that says why."
    why: "The kit's rules, CI and checks are built for the recommended frameworks; WPF and Windows Forms serve Windows alone and are the older stacks (ADR-0059). Before 2026-11-17 this rule sent every desktop app to .NET MAUI and asked an ADR for WinUI 3 too; the owner had it follow Microsoft's recommendation instead (ARC-011)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0008", "ADR-0059", "owner, 2026-11-17"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "an architecture choice; code review checks for the ADR"
    projectTypes: [maui, blazor-hybrid, winui3, wpf, winforms]
    paths: ["**/*.csproj"]
  - id: ARC-012
    statement: "Every tool, service and tier an app uses starts on the industry-standard option while it's free for the app's use; the new-app intake asks for a monthly budget, $0 when unanswered, and within that budget a plan picks the option that fits best; a paid option is always listed with its estimated price, the price's source and the date checked, never dropped; and spending money still needs the owner's OK (SEC-003)."
    why: "One cost policy in place of the parts TST-007, DAT-001 and DAT-006 each stated (rules audit C3, CRF-003). The owner's default is full rigor with free industry-standard tools, wants paid options shown with their price rather than dropped (owner, 2026-11-11), and sets the budget; Well-Architected asks to estimate realistic budgets and to ensure design choices work within the allocated budget."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-11", "owner, 2026-11-12", "ADR-0058", "https://learn.microsoft.com/azure/well-architected/cost-optimization/principles, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/well-architected/cost-optimization/principles"
        retrieved: "2026-11-17"
        text: "Ensure design choices work within the allocated budget to meet the functional and nonfunctional requirements."
    enforcement:
      - kind: gate
        in: [kit]
        how: "check: tools/tests/KitIntake.Tests.ps1 fails when templates/app-intake.json has no budget card with $0 first and as its default, when an unanswered budget doesn't resolve to $0, and (TST-007) when a priced option has no label, price, source or date"
      - kind: advisory
        in: [kit, app]
        how: "picking the best option within the budget is the plan's: the plan-checklist skill's Cost heading points here and to the app profile's budget, and start-work's plan review checks it; spending stays the owner's call (SEC-003)"
    projectTypes: [all]
    paths: ["**"]
  - id: ARC-013
    statement: "Every repo keeps a Mermaid diagram of its modules and the dependencies between them in docs/architecture/modules.md, updated in the same PR as a change that adds a module, a project or a dependency."
    why: "A diagram as code is reviewed and versioned with the code it describes; the Well-Architected architect role lists creating architecture design diagrams among an architect's responsibilities, and ADR-0016 promised docs/architecture/ before any repo had one (rules audit, owner 2026-11-12)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-12", "ADR-0016", "https://learn.microsoft.com/azure/well-architected/architect-role/fundamentals, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/well-architected/architect-role/fundamentals"
        retrieved: "2026-11-17"
        text: "Create architecture design diagrams that illustrate all system design aspects, from a broad overview to detailed dimensions like network and identity."
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: tools/Test-ArchitectureDiagram.ps1 fails when docs/architecture/modules.md is missing or has no non-empty ```mermaid block (kit-checks and app-checks); an app gets a starter page from templates/app"
      - kind: advisory
        in: [kit, app]
        how: "code review checks the diagram matches the change: a new module, project or dependency is on it"
    projectTypes: [all]
    paths: ["**"]
  - id: ARC-015
    statement: "Maintain an architecture decision record (ADR) that captures the context, consequences, and justifications for architectural decisions, and document tradeoffs and rejected options."
    why: "Microsoft lists maintaining an ADR among the solution architect's responsibilities. Split from ARC-005, which adds the kit's template, sections and recommendation."
    layer: outside
    basis: authority
    status: accepted
    ratified: "ADR-0016"
    sources: ["https://learn.microsoft.com/azure/well-architected/architect-role/fundamentals, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/well-architected/architect-role/fundamentals"
        retrieved: "2026-11-17"
        text: "Maintain an architecture decision record (ADR) that captures the context, consequences, and justifications for architectural decisions. Document tradeoffs and rejected options."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that a significant decision has its ADR; ARC-005's check covers the sections"
    projectTypes: [all]
    paths: ["docs/adr/**"]
  - id: ARC-016
    statement: "For a non-trivial monolithic ASP.NET Core application, Clean Architecture is the most appropriate way to structure it: the Application Core holds the business model and the abstractions for infrastructure, Infrastructure implements them, and the UI layer interacts with infrastructure strictly through interfaces defined in the Application Core."
    why: "Microsoft's modern web apps guide says so, for monolithic applications built on ASP.NET Core's dependency injection. ARC-001 is the kit's own shape for it."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures"
        retrieved: "2026-11-17"
        text: "ASP.NET Core's built-in use of and support for dependency injection makes this architecture the most appropriate way to structure non-trivial monolithic applications."
      - source: "https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures"
        retrieved: "2026-11-17"
        text: "This project should reference the Application Core project, and its types should interact with infrastructure strictly through interfaces defined in Application Core."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the shape; ARC-001's architecture tests gate the layer references"
    projectTypes: [web-api, blazor, razor-pages-mvc]
    paths: ["src/**", "sample/**"]
  - id: ARC-017
    statement: "In a .NET MAUI app that uses MVVM, keep view models and views independent: don't reference view types, such as Button and ListView, from view models, and avoid enabling and disabling UI elements in the code-behind, binding them to view model properties instead."
    why: "Microsoft's MVVM page gives these as tips, so view models are tested in isolation."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/architecture/maui/mvvm, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/architecture/maui/mvvm"
        retrieved: "2026-11-17"
        text: "Specifically, don't reference view types, such as Button and ListView, from view models."
      - source: "https://learn.microsoft.com/dotnet/architecture/maui/mvvm"
        retrieved: "2026-11-17"
        text: "Therefore, enable and disable UI elements by binding to view model properties, rather than enabling and disabling them in code-behind."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks views and view models; ARC-010 keeps view models in libraries that can't reference a UI project"
    projectTypes: [maui]
    paths: ["**/*ViewModel*.cs", "**/*.xaml.cs"]
  - id: ARC-018
    statement: "You should use TimeProvider or a similar type when retrieving the time."
    why: "Microsoft's world-ready apps page says so, to make dependencies explicit and testing easier. Split from ARC-008, which bans reading the clock directly and adds the pure-assembly rules."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-16"
    sources: ["https://learn.microsoft.com/dotnet/core/extensions/best-practices-for-developing-world-ready-apps, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/core/extensions/best-practices-for-developing-world-ready-apps"
        retrieved: "2026-11-17"
        text: "You should also use TimeProvider or a similar type when retrieving the time."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks it; ARC-008's bans gate DateTime.Now and the like"
    projectTypes: [all]
    paths: ["**/*.cs"]
  - id: ARC-019
    statement: "Justify every design decision with a business requirement, and avoid over-engineering as well as under-engineering. Don't use CQRS and DDD patterns everywhere: many subsystems are simpler and can be implemented more easily with simple CRUD services."
    why: "Microsoft's Well-Architected simplicity page and its microservices guide say so. Split from ARC-009, which gives the kit's own sizes (modules, projects, patterns) and gates empty projects."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/azure/well-architected/reliability/simplify, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/eshoponcontainers-cqrs-ddd-microservice, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/well-architected/reliability/simplify"
        retrieved: "2026-11-17"
        text: "You must justify every design decision with a business requirement."
      - source: "https://learn.microsoft.com/azure/well-architected/reliability/simplify"
        retrieved: "2026-11-17"
        text: "Avoid overengineering or under-engineering your solution."
      - source: "https://learn.microsoft.com/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/eshoponcontainers-cqrs-ddd-microservice"
        retrieved: "2026-11-17"
        text: "Do not use CQRS and DDD patterns everywhere. Many subsystems, BCs, or microservices are simpler and can be implemented more easily using simple CRUD services or using another approach."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the plan-checklist skill asks for the requirement behind each component, and code review checks"
    projectTypes: [all]
    paths: ["**"]
---

# Architecture

The defaults are Clean Architecture for web apps, and native MAUI with the MVVM Toolkit and Shell for mobile (ADR-0008). Architecture practice follows the Azure Well-Architected Framework (ADR-0016). Diagrams live as Mermaid in `docs/architecture/`, starting with `modules.md` (ARC-013), and are updated in the same PR as the change they describe.

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

## What Microsoft says, and what the kit adds

A rule with `basis: authority` says only what its cited page says, at the page's strength, and stores the sentence. ARC-015 (decision records), ARC-016 (Clean Architecture for non-trivial monoliths), ARC-017 (MAUI view models and views), ARC-018 (TimeProvider) and ARC-019 (justify each decision, no CQRS or DDD everywhere) are those. The kit's own tightenings sit beside them as preferences: ARC-005 (the ADR template and its checks), ARC-001 (the module shape), ARC-008 (the clock ban and pure assemblies) and ARC-009 (how much structure).

## Pending ratification

ARC-010 and ARC-011 were added in auto mode (ADR-0035), so they stay `proposed` until you accept them. The coverage gate's exemption is in force once this change merges, which needs your yes, since it changes a CI check (AGENTS.md, "Working modes").
