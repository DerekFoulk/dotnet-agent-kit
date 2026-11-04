# Spike: how noisy is `latest-all`? (D9, ADR-0009)

**Question:** with the kit's build settings (`AnalysisLevel` `latest-all`, `EnforceCodeStyleInBuild`, warnings as errors, the Microsoft `.editorconfig` baseline), how many warnings does ordinary C# raise, and which rules are candidates for a documented opt-out?

**Date:** 2026-11-04. **SDK:** 10.0.403. This is a first reading on a small sample; step 6 measures again on the real sample solution.

## Method

1. Under `spikes/latest-all/work/` (so the repo's `Directory.Build.props`, `Directory.Packages.props` and `.editorconfig` apply), generate three templates with no extra packages: `dotnet new classlib`, `dotnet new console`, `dotnet new web`.
2. Add about 150 lines of ordinary, idiomatic C#, written the way a typical developer or agent would (not written to trigger rules): a domain model with a record and an enum, a repository and a service with async code, LINQ and exceptions, and minimal API endpoints with logging. The web project references the library.
3. Build each project with warnings left as warnings: `dotnet build <project> --no-incremental -p:TreatWarningsAsErrors=false -p:MSBuildTreatWarningsAsErrors=false`.
4. Count distinct warnings by file, line and rule ID (the web build compiles the library too, so duplicates are removed).

The generated projects were deleted after measuring; the steps above reproduce them.

## Results

**Bare templates:** 3 warnings (IDE0008 ×2, CA1303 ×1).

**With the sample code (about 200 lines of C# in all: the ~150 added lines plus the templates' own): 31 distinct warnings**, about one per 6–7 lines.

| Rule | Count | What it asks for | Verdict |
|---|---|---|---|
| IDE0008 | 12 | An explicit type instead of `var` | Keep. It's STY-002, an owner rule |
| CA2007 | 7 | `ConfigureAwait` on every awaited task | **Opt-out candidate** for application code (below) |
| CA1050 | 2 | Types in namespaces | Keep. Real fix (the request records in `Program.cs`) |
| CA1062 | 2 | Validate arguments of public methods | Keep. Real fix |
| CA1515 | 2 | Make types in an app assembly `internal` | Keep. Real fix; tests reach internals through `InternalsVisibleTo` |
| CA1848 | 2 | `LoggerMessage` source-generated logging | Keep. A performance gain, and agents write the extra code cheaply |
| CA1002 | 1 | `Collection<T>`/`IReadOnlyList<T>` instead of `List<T>` in a public API | Keep. Real fix |
| CA1303 | 1 | No literal strings to `Console.WriteLine` (localization) | **Opt-out candidate** unless the app is localized (below) |
| CA1305 | 1 | Pass a culture to `ToString` | Keep. Real fix |
| CA1873 | 1 | Avoid expensive logging arguments | Keep. Goes away with CA1848's fix |

**Conclusion:** `latest-all` with warnings as errors is workable. Most warnings point to a real improvement and are cheap for an agent to fix. Two rules are noise by Microsoft's own guidance:

- **CA2007.** Microsoft: "It is generally appropriate to suppress the warning entirely for projects that represent application code rather than library code", and in ASP.NET Core "a `ConfigureAwait` wouldn't actually change any behavior". It can be limited to libraries with `dotnet_code_quality.CA2007.output_kind = DynamicallyLinkedLibrary`. Source: [CA2007](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2007), retrieved 2026-11-04.
- **CA1303.** Microsoft: safe to suppress when "the code library will not be localized". Source: [CA1303](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1303), retrieved 2026-11-04.

Each opt-out needs an ADR (STY-003). The owner decides them in the step 5 PR; step 6 re-measures on the sample solution, including test projects, which this spike didn't cover because they need packages.

## Step 6 re-measure: the bookmarks sample (2026-11-04)

The sample (`sample/`: 5 production and 5 test projects, ~190 non-blank lines of production code, ~330 lines of tests) was written test-first under the full kit settings. These are the analyzer errors that stopped a build or `dotnet format --verify-no-changes` along the way, by rule:

| Rule | Where | What it asked for | Verdict |
|---|---|---|---|
| CA1707 | Tests (5) | No underscores in test method names (`Create_rejects_a_blank_title`) | **Decision for the owner** (below) |
| CA1507 | Tests (2) | `nameof` instead of a string literal that matches a parameter name | Keep; renaming the parameter avoids it |
| CA1054 | Tests (1) | `Uri` instead of a string parameter named `url` | Keep; renaming the parameter avoids it |
| CA2000 | Tests (1) | Dispose the factory `WithWebHostBuilder` replaced | Keep; a real leak |
| IDE1006 | Tests (3) | `s_` prefix on a static field | Keep; enforced by `dotnet format`, not the build |
| CA1822, CA1823 | Red-commit stubs (5) | Stubs that ignore their fields | Keep; the stubs touch their fields (`_ = (...)`) |
| CA1716 | Release spike (1) | A namespace that is a keyword in another language (`Lib`) | Keep |

**Conclusion:** `latest-all` stays workable on a real solution; production code needed no opt-out beyond ADR-0029. The one open question is CA1707 in tests. Microsoft's unit-testing guide names tests `Add_SingleNumber_ReturnsSameNumber` (method, scenario, expected result), which CA1707 rejects; its ASP.NET Core architecture guide uses names without underscores (`CallsImageServiceWithId`). The sample uses names without underscores for now. Sources: [Unit testing best practices](https://learn.microsoft.com/dotnet/core/testing/unit-testing-best-practices) and [Test ASP.NET Core MVC apps](https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/test-asp-net-core-mvc-apps), retrieved 2026-11-04.
