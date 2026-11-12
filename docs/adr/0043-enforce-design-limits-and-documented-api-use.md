# ADR-0043: Enforce design limits and documented-API use with Microsoft's analyzers

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

On 2026-11-08 the owner set the craft principles that `docs/standards/craft.md` now records: good fundamentals (SOLID, DRY, KISS and the rest), never a workaround, never settling, enforced in the kit and in every app that uses it. He asked for tools over advice where a tool can see the problem, and later added "add whatever we need to". This ADR covers the parts a tool can check:

1. **Metric limits** (CRF-008): cyclomatic complexity, class coupling, inheritance depth, maintainability.
2. **Documented use of libraries** (CRF-010): no reaching into non-public members.
3. **Namespace cycles** (CRF-007).

What measurement on the kit showed (SDK 10.0.404):

- **`AnalysisLevel latest-all` leaves twelve rules off.** Microsoft's code analysis overview lists eleven, and calls all of them legacy rules that might be deprecated in a future version: the metric rules (CA1501, CA1502, CA1505, CA1506, CA1509) and six design rules (CA1005, CA1014, CA1017, CA1021, CA1045, CA1060). The SDK's own all-mode file (`analysislevel_10_all.globalconfig`) also sets CA1516 to none. So STY-003's "every analyzer rule on" didn't hold. Microsoft's CA1509 page says that rule can only be turned on in a global config, not `.editorconfig`.
- **With those rules on, the sample broke three of them.** (Review 2 of PR 36 corrected the CA1017 count.)
  - CA1506: `ServiceDefaultsTests` coupled to 96 types, over the default of 95 per type, because it held three concerns (health, telemetry, resilience).
  - CA1014 (mark assemblies CLS-compliant): every project.
  - CA1017 (mark assemblies with ComVisible): one project, `Bookmarks.Api`. It fires only on an assembly with a public type in the global namespace (the analyzer's `AssemblyHasPublicTypes`); in the sample that's `Bookmarks.Api`'s `Program`, which ASP.NET Core's source generator declares public (ASP.NET Core 10's release notes).
  - The highest member couplings were the API's top-level `Main` (36 types), test methods (up to 32), `ConfigureOpenTelemetry` (25), `MapDefaultEndpoints` (16) and `BookmarkService.AddAsync` (14). No method came near a cyclomatic complexity of 15.
- **CA1502 doesn't count the arms of a switch expression.** A method whose `switch` expression has four arms reported nothing at a limit of 2, while an `if` chain did.
- **CA1501 counts only base classes in the same module, and fires above the limit.** Microsoft's page says it fires at "five or more levels". Measured, the default limit of 5 fires at 6 levels: the last class in a chain of 7.
- **Banning `BindingFlags.NonPublic` isn't enough.** `TypeInfo.DeclaredFields` and its siblings, `RuntimeReflectionExtensions.GetRuntimeFields` and its siblings, `Activator.CreateInstance(Type, bool)`, the `Expression` factories that look a member up by name, `Expression.New(Type)`, the `Delegate.CreateDelegate` overloads that bind a method by name, and `Assembly.GetTypes`, `DefinedTypes`, `Module.GetTypes` and `FindTypes`, the `PropertyInfo` and `EventInfo` accessor getters that take `nonPublic` (`GetOtherMethods` among them), and their accessor properties (`GetMethod`, `SetMethod`, `AddMethod`, `RemoveMethod`, `RaiseMethod`), all reach non-public members or types with no `BindingFlags`. Each was checked in PowerShell against a type with private members. These are the routes found so far, not a proof that no other exists.
- **One known violation of CRF-010:** `ServiceDefaultsTests` read `TracerProvider`'s non-public `Processor` property by reflection.

This ADR was decided in auto mode (ADR-0035), within the principles the owner set.

## Options

### Option 1: Microsoft's analyzers, with the limits in the kit's config files

- **Metric limits.** Turn the rules on in a root `.globalconfig`, and set the limits in `CodeMetricsConfig.txt`. Warnings fail the build (STY-004). The limits file is an "additional file": a file a project hands to its analyzers along with its code, as Microsoft's CA1502 and CA1506 pages show.
  - **CA1502 at 15, the owner's limit.** Microsoft's cyclomatic complexity page quotes NIST 500-235: 10 is McCabe's original limit, and "limits as high as 15 have been used successfully as well". NIST reserves a limit over 10 for projects with several operational advantages over typical ones. Its examples are experienced staff, formal design, a modern language, structured programming, code walkthroughs and a comprehensive test plan, and it asks for a willingness to spend the extra testing effort. The kit has several of them:
    - formal design: plans with a checklist, and ADRs;
    - a modern language, written in structured style: C#, with no `goto` in the kit's code today;
    - code walkthroughs: the reviewer agent on every PR, and the owner on the PRs his to merge (review mode, guardrails, releases);
    - a comprehensive test plan, with the extra effort spent: test-first, coverage gates and nightly mutation testing (TST-001, TST-004).

    Staff experience is something this ADR can't show.
  - **CA1501, CA1505 and CA1506 at Microsoft's defaults:** 5 levels, a maintainability index of 10, and 40 types per member and 95 per type. STY-003, the owner's rule, already says every analyzer rule is on, so turning them on at Microsoft's own limits adds no new choice. `CodeMetricsConfig.txt` writes the defaults out for methods and types; fields, properties and events keep CA1506's default of 40 without an entry.
  - **Why not lower coupling limits.** Microsoft's class coupling page cites S2010's upper limit of 9 classes that one class uses. But CA1506 counts framework types too: `Task`, `CancellationToken`, `string`. At 9 per type, nearly every class in the sample would fail (`BookmarkService` couples to 21 types, `EfBookmarkRepository` to 19), and so would most methods (`BookmarkService.AddAsync` 14, `MapDefaultEndpoints` 16). A tighter number would be one the kit made up.
- **The other rules `latest-all` leaves off go on too**, each with a fixture: STY-003 asks for them.
  - CA1005, CA1021, CA1045, CA1060 and CA1516: the sample breaks none of them.
  - CA1017: `Directory.Build.props` gives every assembly `[assembly: ComVisible(false)]` through an `AssemblyAttribute` item, the documented MSBuild way to generate an assembly attribute (the WriteCodeFragment task). So no project needs a line of its own, and a type COM must see opts in with `[ComVisible(true)]`.
  - CA1014 stays off for now. Declaring `[assembly: CLSCompliant(true)]` everywhere makes the compiler check CLS compliance, and the sample then breaks it in 48 places (CS3001 to CS3016; CS3016, arrays as attribute arguments, accounts for 24 of them). Whether apps should declare CLS compliance is a decision of its own (GAP-021).
    - **Update (2026-11-11, ADR-0049):** CA1014 is on. `Directory.Build.props` declares every assembly `CLSCompliant(false)`, which is what CA1014's page asks of an assembly that isn't meant to be compliant.
- **Documented use.** `Microsoft.CodeAnalysis.BannedApiAnalyzers` 5.6.0 as a global package reference (a package `Directory.Packages.props` adds to every project at once), plus `BannedSymbols.txt`.
  - The package is Microsoft's, from dotnet/roslyn, MIT, not deprecated, and runs at build time only. dotnet/roslyn documents it as the analyzer for banning APIs, and the owner's "add whatever we need to" covers adding it.
  - The file bans `BindingFlags.NonPublic`, `UnsafeAccessorAttribute`, `UnsafeAccessorTypeAttribute` and the routes above. Each entry names the public alternative. Routes found later join the list.
- **Cycles.** An ArchUnitNET slice rule over the root namespace and every namespace under it. A slice is a group of types, here one per namespace, and the rule fails when any two groups depend on each other in a loop. ArchUnitNET is already the kit's architecture-test tool (TST-005).
- **Trade-offs:** Microsoft's rules match the rest of the analyzer baseline (STY-003) and its documentation, and add no runtime dependency. They don't measure nesting depth, statements per method, file length or cohesion (LCOM4), so those stay advisory (GAP-019).
- **Reversibility:** easy. Each check is one line in a config file.
- **Risk:** low to medium. An update could change how a metric counts; Dependabot PRs build the sample, so a change shows up there first. Microsoft says these rules might be deprecated in a future version; if they are, the metric limits lose their check, and GAP-019's routes (a third-party analyzer, or a kit check) come back on the table.

### Option 2: A third-party analyzer package with more metrics

For example SonarAnalyzer.CSharp, whose rules include nesting depth (S134), method length (S138) and file length (S104).

- **Trade-offs:** more limits checked by a tool. But the package brings hundreds of rules that overlap Microsoft's. The kit would have to turn most of them off, and each opt-out needs an ADR (STY-003). That's many rules to configure and ignore, against the principle that a few enforced rules beat many ignored ones. It also adds a third-party dependency to every app.
- **Reversibility:** moderate. Removing it later changes what every app's build checks.
- **Risk:** medium. License and rule changes come from outside Microsoft's release cycle.

### Option 3: Kit scripts and text searches

A Pester or CI check that searches the code for `BindingFlags.NonPublic` and measures nesting and file length.

- **Trade-offs:** no package. But a text search misses aliases and `using static`, and it flags comments and strings. Nesting needs a C# parser, which would duplicate Roslyn's. File length alone is a cheap line count, one route GAP-019 can take later.
- **Reversibility:** easy.
- **Risk:** medium. A check that misses cases gives false confidence.

An ArchUnitNET rule can't stand in for the ban: an enum value such as `BindingFlags.NonPublic` compiles to a plain integer, so it leaves no dependency to check.

## Recommendation

Option 1. It uses Microsoft's own analyzers at Microsoft's documented settings, adds no runtime dependency, and keeps the set of automated rules small enough that every one of them is enforced.

## Decision

Option 1, decided in auto mode on 2026-11-10 under the owner's principles of 2026-11-08. The limits are 15 for CA1502 (the owner's) and Microsoft's defaults for the rest.

## Consequences

- **New root files, which every new app gets** (Export-KitApp copies them as kit-owned): `.globalconfig`, `CodeMetricsConfig.txt` and `BannedSymbols.txt`.
  - `Directory.Build.props` lists the two `.txt` files as AdditionalFiles.
  - `Directory.Packages.props` adds the analyzer as a global package reference, outside the sample's group, so new apps get it too.
  - Export-KitApp's tests fail if `Directory.Build.props` points at a file an app doesn't get, or if the app's `Directory.Packages.props` lacks a kit global package reference.
- **For the sync job (D3):** an existing app owns its `Directory.Packages.props`, so the kit's files alone would leave it with `BannedSymbols.txt` and no analyzer to read it. The sync job must carry the kit's global package references into an app's `Directory.Packages.props`. Until it does, CRF-010's build check reaches only apps created after this change.
- **Tests:**
  - `tools/tests/BuildConfig.Tests.ps1` builds one fixture for each check that must fail: each metric just over its limit, each other rule `.globalconfig` turns on, a malformed limit, and routes on the ban list. Its "violations fail the build" table is the list; a test there fails if a rule `.globalconfig` turns on has no row.
  - It builds one at each limit that must pass (complexity 15, coupling 40 and 95, depth 5, maintainability 10), so a limit can't quietly drift.
  - It checks that every `BannedSymbols.txt` entry names a symbol declared on the type it names, since the analyzer ignores one that doesn't, and that CRF-008's numbers match `CodeMetricsConfig.txt`.
  - The sample's `NamespaceCycleTests` proves the rule catches a cycle between two fixture namespaces, and one through a type in the root namespace itself. It also proves the rule fails when nothing sits under its root, since ArchUnitNET passes a slice rule that matches nothing, and accepts a root whose only types sit in the root itself. Then it checks the sample.
- **The sample changed to meet the rules.**
  - `ServiceDefaultsTests` became `HealthEndpointTests`, `TelemetryTests`, `ResilienceTests` and a small `ServiceDefaultsTests` for the argument guards.
  - The OTLP export test now sends the exporter's documented named HttpClients (`OtlpTraceExporter`, `OtlpMetricExporter`, `OtlpLogExporter`; the exporter's README for 1.20.1) to a recording handler, and flushes with the public `ForceFlush`. It no longer reads the non-public `Processor` property. The exporter sends synchronously, so a handler must override `Send` as well as `SendAsync`, as the exporter's API documentation says.
- **Known gaps, in the scorecard.**
  - GAP-019: no tool checks nesting, statements per method, file length or LCOM4.
  - GAP-020: no tool finds duplicated code.
  - GAP-021: CA1014 is still off. **Update (2026-11-11):** closed by ADR-0049.
  - Some cases slip past a check today: a long switch expression (CA1502), and routes into internals not on the list yet (the ban). craft.md's "What the checks miss" keeps the list. The reviewer agent checks both. A follow-up PR adds them to its checklist, which is a guardrail, so the owner merges that one.
- **Exceptions:** craft.md's "Exceptions" section says when a suppression needs an ADR (CRF-008, CRF-010, STY-003).
- **Harder now:** a class that grows past 95 collaborators has to be split, and code that needs a library's internals has to find a documented way in. Both are intended.

## Pillars affected

- **Operational excellence:** the metric limits keep code maintainable, and the build enforces them in every new app.
- **Reliability:** code that depends only on documented APIs doesn't break when a library changes its internals in a patch release.
- **Security:** no reaching into another assembly's private state.
- **Cost optimization:** none; the analyzer is free and runs at build time.
- **Performance efficiency:** none at run time. The build does a little more analysis.

## Sources

- owner, 2026-11-08
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1501, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1502, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1506, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1509, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/configuration-files, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/visualstudio/msbuild/writecodefragment-task, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-10.0 (a source generator declares `public partial class Program`), retrieved 2026-11-11
- https://github.com/dotnet/sdk/blob/748f0c98b36da3cde0e7b47e3363203bf3feb9ff/src/Microsoft.CodeAnalysis.NetAnalyzers/src/Microsoft.CodeAnalysis.NetAnalyzers/Microsoft.CodeQuality.Analyzers/ApiDesignGuidelines/MarkAssembliesWithComVisible.cs (CA1017's `AssemblyHasPublicTypes`; the analyzers moved from dotnet/roslyn-analyzers to dotnet/sdk), retrieved 2026-11-11
- C:\Program Files\dotnet\sdk\10.0.404\Sdks\Microsoft.NET.Sdk\analyzers\build\config\analysislevel_10_all.globalconfig (CA1516 set to none), read 2026-11-10
- https://learn.microsoft.com/en-us/visualstudio/code-quality/code-metrics-cyclomatic-complexity, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/visualstudio/code-quality/code-metrics-class-coupling, retrieved 2026-11-10
- https://github.com/dotnet/roslyn/blob/c0573ed0a7dc3e3b4d2e70da47f97cc51a35524f/src/RoslynAnalyzers/Microsoft.CodeAnalysis.BannedApiAnalyzers/BannedApiAnalyzers.Help.md, retrieved 2026-11-10
- https://api.nuget.org/v3/registration5-gz-semver2/microsoft.codeanalysis.bannedapianalyzers/index.json (versions, listing dates, deprecation), retrieved 2026-11-10. It lists 5.0.0, 5.3.0 and 5.6.0 all on 2026-07-02, within four minutes of each other, so that date is probably when they were listed again, not first released.
- https://archunitnet.readthedocs.io/en/latest/guide/, retrieved 2026-11-10
- https://github.com/open-telemetry/opentelemetry-dotnet/blob/core-1.20.1/src/OpenTelemetry.Exporter.OpenTelemetryProtocol/README.md, retrieved 2026-11-10
