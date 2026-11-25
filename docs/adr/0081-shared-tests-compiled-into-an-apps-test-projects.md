# ADR-0081: The kit's shared tests compile into an app's own test projects

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
- The sample's Architecture.Tests keeps only its `AppLayers.cs`. Its LayerTests, SharedLibraryTests and NamespaceCycleTests moved into the shared source. SharedLibraryTests and NamespaceCycleTests check what they did. The rest changed:
  - **Layer dependencies** are read from each assembly's references, not from ArchUnitNET's type dependencies. The compiler records a reference only to an assembly whose code it uses, so this is as strict between assemblies.
  - **Each theory runs once per declared assembly**, so a module added later is checked without a new test.
  - **The endpoint check** looks at classes named `...Endpoints` or `...Controller`. In an API (an assembly named `.Api`) it fails when it finds none, as the sample's did, so endpoints moved under another name don't pass unchecked. In another front end, such as a web UI, it checks whatever it finds, which may be nothing. Endpoints mapped in another class, or in `Program.cs`, aren't seen. Code review checks those, and so does the OpenAPI part of SEC-013 (the ContractTests).

**Rules:**

- ARC-001, ARC-003, CRF-006, CRF-007, CRF-014 and SEC-013's endpoint part now gate in apps too (`in: [kit, app]`), once the app has an Architecture.Tests project.
- SEC-013's OpenAPI part stays advisory for apps until the host checks.

**Tests and docs:**

- `tools/tests/Export-KitApp.Tests.ps1` builds an exported app with a domain and an infrastructure project. Its Architecture.Tests passes. Once the domain uses the infrastructure, it fails, naming both.
- `docs/standards/testing.md` ("Shared tests") and the app's AGENTS.md describe it.

**Next:** the host checks follow in their own PR, with the same pattern for `*.FunctionalTests`. GAP-037 stays open until then.

**An app that already copied the sample's architecture tests** has to do three things at its next sync. Its build fails until it does the last two, and the first keeps each check from running twice.
- Delete its copies.
- Drop its own `TngTech.ArchUnitNET.xUnitV3` reference, which `tests/Directory.Build.props` now adds (NU1504 otherwise).
- Add its `AppLayers.cs`, as the sample's.

The sync PR's CI build fails until then, so the change shows on that PR.

**Update (2026-11-16): the host checks.** `tools/AppTests/Functional` holds them, and `tests/Directory.Build.props` compiles them into every `*.FunctionalTests` project.

- **The app's part of `AppHost`:**
  - `Start(environment, settings, services)` starts the app with its own test database and sign-in, with ValidateScopes and ValidateOnBuild on, and returns it as an `IAppUnderTest`: its `Services`, and `CreateClient(signedIn)`.
  - `AnonymousRoutes` lists the routes that may be called anonymously.
  - `SignedInRoute` names a route a signed-in user may GET. The hosting checks send their requests there, since a route with no endpoint would pass a CORS check whatever the app's endpoints allow.
  - `ServesHttpApi` says whether the app serves an HTTP API. `ErrorTests` and `OpenApiTests` skip when it doesn't, as in a Blazor web app with no API of its own, since API-002 and API-003 cover HTTP APIs.
  - The sample's `AppHost.cs` starts it through its `ApiHost`.
- **The checks:**
  - `HealthTests` (OPS-002).
  - `ErrorTests` (API-002): a route that doesn't exist, and an unhandled exception. The exception is thrown by a branch a startup filter adds after the app's pipeline, so it passes through the app's own exception handler.
  - `OpenApiTests` (API-003).
  - `DependencyInjectionTests` (CRF-013), with probe services of its own.
  - `TelemetryTests` (OPS-001) and `ResilienceTests` (OPS-003).
  - `ShutdownTests` (OPS-005).
  - `AuthorizationTests` (SEC-007): the fallback policy, and the anonymous routes against the app's list.
  - `HostingSecurityTests` (SEC-011): host filtering, HSTS, CORS, the Server header and the body cap.
  - The sample's copies of these went (CRF-003). It keeps its own: its database and live checks, its health timeout, its rate limit, its errors and its tokens.
- **Rules:** nine rules gain a gate in apps (`in: [kit, app]`), each for the parts above: API-002, API-003, CRF-013, OPS-001, OPS-002, OPS-003, OPS-005, SEC-007 and SEC-011.
- **What stays advisory, and why:**
  - **The app's own behavior** (API-004, API-006, API-007, SEC-009, SEC-010, OPS-006), SEC-011's rate limit and `/health`'s database check need the app's own endpoints, data or settings. They're its own tests' to check, as the sample's do, and code review's. GAP-027's check will require the projects.
  - **TST-003 and UI-001:** TST-003 is GAP-027's, and UI-001 is UI-002's.
- **GAP-037 stays open, narrowed** to what a shared check could still take on:
  - the OpenAPI document's checks: API-002's declared errors as Problem Details, API-003's snapshot, and SEC-013's schemas;
  - SEC-008's token rejections that need no app key (an unsigned token, one signed with another key) and its bearer scheme in the document;
  - a second host, such as a web UI beside an API, which the checks don't start.
  - They wait because each needs another hook in the app's part (its document's path and snapshot folder, its Contracts assembly, a second host), and the owner asked for this part to land quickly.
- **Packages:** the checks use OpenTelemetry's and Microsoft.Extensions.Http.Resilience's types. An app's FunctionalTests gets them through its API's ServiceDefaults project (OPS-001). An app without one doesn't build its FunctionalTests until it has one.
- **Proof:** `tools/tests/SharedHostChecks.Tests.ps1` checks that every shared check compiles into the sample's FunctionalTests, which runs them in the kit's CI.
  - **Not verified:** an exported app's FunctionalTests, which would need a whole web app with ServiceDefaults and sign-in. The export copies `tools/AppTests` whole, the path the architecture tests' export test covers.

**An app that already has a FunctionalTests project** has to do two things at its next sync. Its build fails until it adds the part, so the change shows on the sync PR.
- Add its `AppHost.cs`, as the sample's, starting the app through its own host.
- Delete any copies of the sample's tests that the shared checks now run, so none runs twice and the duplicate code check doesn't report them.

**One Architecture.Tests project per app**, as TST-003 says. A second one would compile the same `.kit` files again, and the duplicate code check would report each one as a copy of itself.

**What gets harder:** the shared source must stay within the kit's analyzers and limits in every app. Its tests run in each app's own test run, so a breaking change in it fails every app's CI at its next sync. The sample's CI is the first to see one.

**Update (2026-11-18): CRF-014 split.** ADR-0082 split CRF-014: it keeps Microsoft's encapsulation, gated by the analyzers, and the owner's tightening (state kept valid, a persistence-ignorant domain) is CRF-021. The domain's persistence check named above as CRF-014's now gates CRF-021.

**Update (2026-11-25): the rest of GAP-037.** The owner chose on 2026-11-25 to land it before v0.1.0, as an approved exception to the coming freeze on new checks.

- **Every host:** the app's part of `AppHost` now lists its hosts (`Hosts`), such as an API and a web UI beside it, since TST-003 gives an app one FunctionalTests project, which must start each.
  - Each host is a `HostUnderTest`, with the members the single host had (`Start`, `AnonymousRoutes`, `SignedInRoute`, `ServesHttpApi`), a `Name`, and `ContractAssemblies`, the assemblies its endpoints' types may come from (SEC-013).
  - `EachHost`, an xUnit v3 data attribute, gives every check one row per host, with the host's name first, listed before the run. Each check starts the host its row names. No check can start "the" app, because nothing in the shared source starts one any other way.
  - `EachHostTests` checks that every shared check takes its rows from `EachHost`, and the rows for two hosts. It also refuses an empty list, a repeated name, and a name that can't name a folder, since the name also names the host's snapshot folder.
- **The OpenAPI document's checks**, for each host that serves an HTTP API:
  - `OpenApiTests` (API-003) compares the Development document with `Contract/<host name>/openapi-v1.json` in the FunctionalTests project. On a mismatch it writes `openapi-v1.received.json` beside it, which git ignores. `tests/Directory.Build.props` records the project's folder as `ProjectDirectory` assembly metadata for every `*.FunctionalTests` project; the sample's project file did that before. The sample's snapshot moved to `Contract/Bookmarks.Api/`.
  - `OpenApiDocumentTests` checks that every error the document declares is Problem Details (API-002): a 4xx, a 5xx, a range, and the default response. It also checks the Bearer scheme, and that every operation not on one of the host's anonymous routes requires it and declares 401 and 403 (SEC-007, SEC-008). Route constraints are stripped before the two are compared.
  - `ContractTypeTests` (SEC-013) reads the types from ApiExplorer, which the document is made from. Every type an endpoint takes as a body or form, or answers with, must come from the host's `ContractAssemblies` or be .NET's own, and so must its generic arguments and array elements. ".NET's own" means signed with one of Microsoft's public key tokens, which covers ProblemDetails.
    - **Why types, not schema names:** ASP.NET Core composes the names of generic schemas (`OkOfArrayOfTodo`), and its customization page says those details may change. A name check would fail an app with a generic page type in its Contracts.
    - **Why ApiExplorer:** it's in the shared framework, so the check compiles in every app without the OpenAPI package. It also covers endpoints mapped in `Program.cs`, which the architecture tests' EndpointTests don't see.
- **SEC-008's token checks:** `TokenTests` sends four callers to the host's signed-in route and expects a 401 Problem that names the Bearer scheme:
  - no token;
  - an unsigned token (`alg: none`);
  - the signed-in client's token with a claim added after it was signed;
  - an RS256 token signed with a new key, with a key id of its own.

  Each is made with the BCL only, from the token the host's signed-in client sends, so none needs the app's key, issuer or audience. The untouched token getting through is the control. A host that serves an HTTP API must send a JWT bearer token from `CreateClient(signedIn: true)`: SEC-008 says an HTTP API takes them. Without one, the check fails rather than skips.
- **The sample** keeps only its own:
  - the create request's limits in the document (SEC-010);
  - no token, an expired token, another issuer and another audience on every bookmarks endpoint, which need its key.

  Its copies of the moved checks went (CRF-003).
- **Rules:** SEC-008 and SEC-013's document part gain a gate in apps. API-002 and API-003 now gate the document's errors and its snapshot in apps too.
- **Proof:** the sample runs every check in the kit's CI. Locally, on 2026-11-25, a broken sample failed the check meant for each break:
  - dropping the bearer document transformer;
  - declaring a bare 404;
  - answering with a list of domain `Bookmark`s;
  - accepting any signature.
- **Not verified:**
  - a real second host. The sample has one, so only `EachHostTests` shows the rows for two.
  - an exported app's FunctionalTests, for the reason the first host-checks update gives.
- **GAP-037 closed.** What stays with an app's own tests is there by design: its own endpoints, data and settings, and tokens only its key can sign.

**An app that already has a FunctionalTests project** has to do these at its next sync. Its build fails until it does the first two.
- Turn its `AppHost.cs` into a `Hosts` list of `HostUnderTest`s, as the sample's.
- Name each host's `ContractAssemblies`.
- Move its snapshot, if it kept one, to `Contract/<host name>/openapi-v1.json`, and drop its own `ProjectDirectory` metadata item, which `tests/Directory.Build.props` now adds.

## Pillars affected

- **Reliability and Operational Excellence:** an app gets the kit's architecture gates from its first Architecture.Tests project, in its own `dotnet test`, and keeps them current through the sync.
- **Security:** SEC-013's endpoint check now runs in every app, so a domain type can't leak through an endpoint class unseen; since the 2026-11-25 update, ContractTypeTests checks every endpoint's types, wherever it's mapped, and TokenTests that an HTTP API refuses an unsigned, changed or untrusted token.
- **Cost Optimization:** free; the tests take about a second.
- **Performance Efficiency:** not affected.

## Sources

- owner, 2026-11-16 ("Finish the free gaps")
- owner, 2026-11-25 (GAP-037 before v0.1.0, an exception to the freeze on new checks)
- https://learn.microsoft.com/aspnet/core/fundamentals/openapi/customize-openapi#customize-schema-reuse, retrieved 2026-11-25
- https://learn.microsoft.com/en-us/visualstudio/msbuild/customize-by-directory, retrieved 2026-11-16
- https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/partial-member, retrieved 2026-11-16
- https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures, retrieved 2026-11-07
