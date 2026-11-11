# ADR-0043: Enforce design limits and documented-API use with Microsoft's analyzers

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

On 2026-11-08 the owner set the craft principles that `docs/standards/craft.md` now records: good fundamentals (SOLID, DRY, KISS and the rest), never a workaround, never settling, enforced in the kit and in every app that uses it. He asked for tools over advice where a tool can see the problem, and later added "add whatever we need to". This ADR covers the parts a tool can check:

1. **Metric limits** (CRF-008): cyclomatic complexity, class coupling, inheritance depth.
2. **Documented use of libraries** (CRF-010): no reflection into non-public members.
3. **Namespace cycles** (CRF-007).

What measurement on the kit showed (SDK 10.0.404):

- **Microsoft's metric rules are off, even under `AnalysisLevel latest-all`.** CA1501, CA1502, CA1506 and CA1509 each need an explicit severity. Microsoft's CA1509 page says it can only be turned on in a global config, not `.editorconfig`.
- **With the rules on, the sample had one violation.** `ServiceDefaultsTests` coupled to 96 types, over CA1506's default of 95 per type; it held three concerns (health, telemetry, resilience). The highest member values were the API's top-level `Main` (36 types), test methods (up to 32), `ConfigureOpenTelemetry` (25), `MapDefaultEndpoints` (16) and `BookmarkService.AddAsync` (14). No method came near a cyclomatic complexity of 15.
- **CA1502 doesn't count the arms of a switch expression.** A method whose `switch` expression has four arms reported nothing at a limit of 2, while an `if` chain did.
- **CA1501 counts the base classes in the same module.** In a chain of 6 classes, the last is 5 deep, so the default limit of 5 fires from 7 classes. Microsoft's example implies 6.
- **One known violation of CRF-010:** `ServiceDefaultsTests` read `TracerProvider`'s non-public `Processor` property by reflection.

This ADR was decided in auto mode (ADR-0035), within the principles the owner set.

## Options

### Option 1: Microsoft's analyzers, with the limits in the kit's config files

- **Metric limits.** Turn on CA1501, CA1502, CA1506 and CA1509 in a root `.globalconfig`. Set the limits in `CodeMetricsConfig.txt`, an AdditionalFiles item, as Microsoft's CA1502 and CA1506 pages show. Warnings fail the build (STY-004).
  - **CA1502 at 15.** NIST 500-235, which Microsoft's cyclomatic complexity page quotes, sets 10 as McCabe's limit and allows up to 15 for projects with "a comprehensive test plan". The kit has one: test-first, coverage gates and nightly mutation testing (TST-001, TST-004).
  - **CA1506 at Microsoft's defaults: 40 types per member, 95 per type.** Microsoft's class coupling page cites S2010's limit of 9 per member, but CA1506 counts framework types too: `Task`, `CancellationToken`, `string`. At 9, `BookmarkService.AddAsync` (14), `MapDefaultEndpoints` (16) and every test method would fail. A tighter limit would be a number the kit made up. The defaults are explicit in the file, so they're visible and pinned.
  - **CA1501 at Microsoft's default of 5.**
- **Documented use.** `Microsoft.CodeAnalysis.BannedApiAnalyzers` 5.6.0, a global package reference, plus `BannedSymbols.txt`. The package is Microsoft's, from dotnet/roslyn, MIT, not deprecated, and runs at build time only. The file bans `BindingFlags.NonPublic`, `UnsafeAccessorAttribute` and `UnsafeAccessorTypeAttribute`.
- **Cycles.** An ArchUnitNET slice rule (ArchUnitNET is already the kit's architecture-test tool, TST-005) over every namespace under the app's root.
- **Trade-offs:** Microsoft's rules match the rest of the analyzer baseline (STY-003) and its documentation, and add no runtime dependency. They don't measure nesting depth, statements per method, file length or cohesion (LCOM4), so those stay advisory (GAP-019).
- **Reversibility:** easy. Each check is one line in a config file.
- **Risk:** low. An update could change how a metric counts; Dependabot PRs build the sample, so a change shows up there first.

### Option 2: A third-party analyzer package with more metrics

Some third-party analyzers measure nesting depth, method length and file length as well.

- **Trade-offs:** more limits checked by a tool. But each package brings hundreds of rules that overlap Microsoft's. The kit would have to turn most of them off, and every opt-out needs an ADR (STY-003). That is many rules to configure and ignore, against the principle that a few enforced rules beat many ignored ones. It also adds a third-party dependency to every app.
- **Reversibility:** moderate. Removing it later changes what every app's build checks.
- **Risk:** medium. Licence and rule changes come from outside Microsoft's release cycle.

### Option 3: Kit scripts and text searches

A Pester or CI check that searches the code for `BindingFlags.NonPublic` and measures nesting and file length.

- **Trade-offs:** no package. But a text search misses aliases and `using static` and flags comments and strings. And the kit would own parsers that duplicate Roslyn's.
- **Reversibility:** easy.
- **Risk:** medium. A check that misses cases gives false confidence.

An ArchUnitNET rule can't stand in for the ban: an enum value such as `BindingFlags.NonPublic` compiles to a plain integer, so it leaves no dependency to check.

## Recommendation

Option 1. It uses Microsoft's own analyzers at Microsoft's documented settings, adds no runtime dependency, and keeps the set of automated rules small enough that every one of them is enforced.

## Decision

Option 1, decided in auto mode on 2026-11-10 under the owner's principles of 2026-11-08. The limits in `CodeMetricsConfig.txt` are 15 for CA1502, 40 per member and 95 per type for CA1506, and 5 for CA1501.

## Consequences

- **New root files, which every app gets** (Export-KitApp copies them as kit-owned): `.globalconfig`, `CodeMetricsConfig.txt` and `BannedSymbols.txt`. `Directory.Build.props` lists the two `.txt` files as AdditionalFiles. `Directory.Packages.props` adds the analyzer as a global package reference, outside the sample's group, so apps get it too. A Pester test fails if `Directory.Build.props` points at a file an app doesn't get.
- **Tests.** `tools/tests/BuildConfig.Tests.ps1` builds a fixture for each check that must fail (complexity 16, coupling 41 and 96, depth 6, a malformed limit, non-public reflection, `UnsafeAccessor`). It also builds one at each limit that must pass (15, 40, 95, 5), so a limit can't quietly drift lower. The sample's `NamespaceCycleTests` proves the rule catches a cycle between two fixture namespaces, then checks the sample. ArchUnitNET passes a slice rule that matches nothing, so the rule also requires types under its root.
- **The sample changed to meet the rules.** `ServiceDefaultsTests` became `HealthEndpointTests`, `TelemetryTests`, `ResilienceTests` and a small `ServiceDefaultsTests` for the argument guards. The OTLP export test now sends the exporter's documented named HttpClients (`OtlpTraceExporter`, `OtlpMetricExporter`, `OtlpLogExporter`; the exporter's README for 1.20.1) to a recording handler and flushes with the public `ForceFlush`. Before, it read the non-public `Processor` property. The exporter sends synchronously, so a handler must override `Send` as well as `SendAsync`, as the exporter's API documentation says.
- **Known gaps, recorded in the scorecard.** GAP-019: no tool checks nesting, statements per method, file length or LCOM4. GAP-020: no tool finds duplicated code. Two cases slip past a check today: a long switch expression (CA1502) and a cast such as `(BindingFlags)32` (the ban). The reviewer agent checks both.
- **Exceptions** are safety nets under CRF-001: a suppression carries its reason. Raising a limit or lifting a ban needs an ADR (STY-006).
- **Harder now:** a class that grows past 95 collaborators has to be split, and a test that needs a library's internals has to find a documented way in. Both are intended.

## Pillars affected

- **Operational excellence:** the metric limits keep code maintainable, and the build enforces them in every app.
- **Reliability:** code that depends only on documented APIs doesn't break when a library changes its internals in a patch release.
- **Security:** no reflection into another assembly's private state.
- **Cost optimization:** none; the analyzer is free and runs at build time.
- **Performance efficiency:** none at run time. The build does a little more analysis.

## Sources

- owner, 2026-11-08
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1502, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1506, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1509, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1501, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/configuration-files, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/visualstudio/code-quality/code-metrics-cyclomatic-complexity, retrieved 2026-11-10
- https://learn.microsoft.com/en-us/visualstudio/code-quality/code-metrics-class-coupling, retrieved 2026-11-10
- https://github.com/dotnet/roslyn/blob/c0573ed0a7dc3e3b4d2e70da47f97cc51a35524f/src/RoslynAnalyzers/Microsoft.CodeAnalysis.BannedApiAnalyzers/BannedApiAnalyzers.Help.md, retrieved 2026-11-10
- https://api.nuget.org/v3/registration5-gz-semver2/microsoft.codeanalysis.bannedapianalyzers/index.json (versions, publish dates, deprecation), retrieved 2026-11-10
- https://archunitnet.readthedocs.io/en/latest/guide/, retrieved 2026-11-10
- https://github.com/open-telemetry/opentelemetry-dotnet/blob/core-1.20.1/src/OpenTelemetry.Exporter.OpenTelemetryProtocol/README.md, retrieved 2026-11-10
