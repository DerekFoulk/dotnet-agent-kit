# ADR-0079: The kit's shared tests compile into an app's own test projects

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

GAP-037 lists 24 rules whose only gate is a test in the kit's sample app or web UI fixture. An app gets the rules but not the tests, so for an app each rule says "advisory, until the app follows the sample" (ADR-0063). The owner chose on 2026-11-16 to finish the free gaps before v0.1.0, and this is one.

The 24 rules fall into four groups:

- **The same in every app, from its compiled code** (6): ARC-001, ARC-003, CRF-006, CRF-007, CRF-014 and the endpoint part of SEC-013. They check which layers an assembly references and which namespaces depend on each other. The sample's Architecture.Tests check them with ArchUnitNET (ADR-0003).
- **The same in every app, from its running host** (10): parts of API-002 and API-003, CRF-013, OPS-001, OPS-002, OPS-003, OPS-005, SEC-007, SEC-008 and SEC-011. These are health endpoints, Problem Details for an unknown route, the OpenAPI document hidden in Production, container validation, shutdown timeout, telemetry, the resilience handler, sign-in required by default, and host filtering and HSTS. Checking them means starting the app, which needs its own test database and sign-in. The sample's FunctionalTests start it through their `ApiHost`.
- **Each app's own behavior** (6): API-004 (paging), API-006 and SEC-010 (validation of each field), API-007 (201 with a Location), SEC-009 (each user sees only their data) and OPS-006 (each settings section validated). A test needs the app's own endpoints and data.
- **Others' gaps** (2): TST-003, whose missing-project check is GAP-027, and UI-001, which an app's own axe tests gate once it writes them (UI-002).

The decision has some constraints:

- An app starts with no projects (ADR-0032).
- A kit file in an app is replaced by the sync at each kit release (ADR-0044).
- Publishing a package is a public release, which is the owner's call (ADR-0078 weighed the same thing for the code shape tool).
- ARC-009's empty-projects check fails a project with no source of its own (ADR-0052).

## Options

### Option 1: Shared test source, compiled into the app's own test projects

The kit writes each shared test once, in `tools/AppTests`. The export puts it in an app's `.kit/tools/AppTests`, as ADR-0078 does for the code shape tool. `tests/Directory.Build.props` is the kit's test settings, which every app gets and the sync keeps current. It compiles the shared tests into the app's TST-003 projects by name: the architecture tests into `*.Architecture.Tests`, and later the host checks into `*.FunctionalTests`.

The test project supplies what only the app knows, in its own part of a partial class:

- for the architecture tests, its assemblies by layer (`AppLayers`);
- for the host checks, how to start it with its test database and sign-in.

That part is the project's own code, so ARC-009's check passes. The project doesn't build until the part exists, so an app can't drop it by accident.

- **Trade-offs:** One source for each test (CRF-003): the sample's own copies go, and it runs the shared tests through its own part, so the kit's CI proves them. They run in `dotnet test` like the app's other tests: in the shared CI with no workflow change, locally, and under the coverage and mutation runs. A fix reaches every app with the next sync. An app needs the TST-003 project for the gate to apply. Until GAP-027's check, an app without one isn't checked.
- **Reversibility:** Easy. Dropping the include from `tests/Directory.Build.props` leaves each app's part as an unused partial, to delete.
- **Risk:** Low to medium. The shared source must build under every app's analyzers, which are the kit's (STY-003), and a newer SDK's new warning would fail them all at once; the sample's build catches it first. A layer project left out of `AppLayers` would go unchecked, so a test fails when a project the tests reference has a layer's name ending but isn't declared.

### Option 2: Test projects in the app template

`templates/app` gets an Architecture.Tests and a FunctionalTests project, copied once into each new app, which then owns and edits them.

- **Trade-offs:** Familiar: an app's tests look like the sample's. But an app has no production code at first, so the projects would have nothing to reference or compile against. Once the app edits them, a kit fix can't reach them: the copies drift, the problem the sync exists to solve (ADR-0032). The sample keeps its own copy as a third source.
- **Reversibility:** Medium: each app's copies are its own.
- **Risk:** Medium: drift, and template projects that don't build.

### Option 3: A kit check the shared CI runs over the built app

A kit tool, like Kit.CodeShape, reads the app's built assemblies after the build and checks layer references and namespace cycles.

- **Trade-offs:** No app code at all, and it can't be skipped by leaving out a project. But it covers only the first group. It can't start the app to check the second, since it doesn't know the app's database or sign-in. It's a second test runner beside `dotnet test`, and the layers would have to be guessed from project names. Package names can end the same way (`Microsoft.AspNetCore.Components.Web`).
- **Reversibility:** Easy.
- **Risk:** Medium: guessed layers, and half the rules left out.

### Option 4: Publish the shared tests as a NuGet test library

- **Trade-offs:** The usual way to share test code. But it means publishing a package, which is the owner's call, and a release pipeline before the kit's v0.2.0 move to a .NET tool (ADR-0078, Option 2).
- **Reversibility:** Medium.
- **Risk:** Medium.

## Recommendation

Option 1: it keeps one source per test, runs where the app's tests already run, and reaches the host checks, which Option 3 can't.

## Decision

Accepted (auto mode, 2026-11-16): the owner asked for the free gaps to be finished, and Option 1 needs no publish, package or money.

## Consequences

**The architecture tests:**

- `tools/AppTests/Architecture` holds them: `LayerTests`, `SharedLibraryTests`, `EndpointTests`, `NamespaceCycleTests` with its fixtures, and `DeclarationTests`.
- `sample/Directory.Build.props`, which an app gets as `tests/Directory.Build.props`, compiles them into every `*.Architecture.Tests` project and adds ArchUnitNET. It reads them from `.kit/tools/AppTests` when that folder exists, otherwise from `tools/AppTests`.
- The sample's Architecture.Tests keeps only its `AppLayers.cs`. Its LayerTests, SharedLibraryTests and NamespaceCycleTests moved into the shared source, with ArchUnitNET's checks unchanged.
- Two changes from the sample's copies:
  - Layer dependencies are read from each assembly's references, since the compiler records a reference only to an assembly whose code it uses.
  - Each theory runs once per declared assembly, so a module added later is checked without a new test.

**Rules:**

- ARC-001, ARC-003, CRF-006, CRF-007, CRF-014 and SEC-013's endpoint part now gate in apps too (`in: [kit, app]`), once the app has an Architecture.Tests project.
- SEC-013's OpenAPI part stays advisory for apps until the host checks.

**Tests and docs:**

- `tools/tests/Export-KitApp.Tests.ps1` builds an exported app with a domain and an infrastructure project. Its Architecture.Tests passes. Once the domain uses the infrastructure, it fails, naming both.
- `docs/standards/testing.md` ("Shared tests") and the app's AGENTS.md describe it.

**Next:** the host checks follow in their own PR, with the same pattern for `*.FunctionalTests`. GAP-037 stays open until then.

**What gets harder:** the shared source must stay within the kit's analyzers and limits in every app. Its tests run in each app's own test run, so a breaking change in it fails every app's CI at its next sync. The sample's CI is the first to see one.

## Pillars affected

- **Reliability and Operational Excellence:** an app gets the kit's architecture gates from its first Architecture.Tests project, in its own `dotnet test`, and keeps them current through the sync.
- **Security:** SEC-013's endpoint check now runs in every app, so a domain type can't leak through an endpoint unseen.
- **Cost Optimization:** free; the tests take about a second.
- **Performance Efficiency:** not affected.

## Sources

- owner, 2026-11-16 ("Finish the free gaps")
- https://learn.microsoft.com/en-us/visualstudio/msbuild/customize-by-directory, retrieved 2026-11-16
- https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/partial-member, retrieved 2026-11-16
- https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures, retrieved 2026-11-07
