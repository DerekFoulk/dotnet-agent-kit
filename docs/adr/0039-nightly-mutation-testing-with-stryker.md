# ADR-0039: Run mutation testing nightly with Stryker.NET, through a shared workflow

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

TST-004 asks for a mutation score of at least 85%, checked nightly. Until now nothing ran it, so that part of the rule was advisory (scorecard GAP-003).

Mutation testing changes the code in small ways, called mutants: a `>` becomes `>=`, a guard is removed, a string is emptied. Then it runs the tests against each mutant. A mutant the tests don't notice "survived". The mutation score is the share of mutants the tests killed. Line coverage only says code ran; the mutation score says the tests would notice if it were wrong.

TST-005 already names Stryker.NET as the kit's mutation tool. Stryker.NET 5.0.0 (11 September 2026) targets .NET 10 and has a Microsoft Testing Platform runner (`test-runner: mtp`, marked preview), which the kit's xUnit v3 test projects need. Its documentation doesn't mention `.slnx` solutions; the kit's runs show they work.

This ADR was decided in auto mode (ADR-0035).

## Options

### Option 1: A shared nightly workflow for the kit and every app

`mutation.reusable.yml` runs Stryker.NET over the whole solution and fails below 85%. The kit calls it nightly, on demand, and on a pull request that changes the sample or the mutation setup. Every new app gets a nightly caller from `templates/app`.

Each fact lives in one place, in the kit, which the workflow reads at its own pinned version:
- **The version** is in `.config/dotnet-tools.json`, .NET's tool manifest, which Dependabot keeps current with the NuGet packages.
- **Every setting** is in `.config/stryker-config.json`: the MTP runner, Release builds, the thresholds (break at 85), the reporters, and `ignore-methods: ConfigureAwait`. `ConfigureAwait(true)` can't change behaviour without a synchronization context, so no test could ever kill that mutant. A person running Stryker locally uses the same file.
- **Coverage stays per test,** Stryker's default: each mutant runs only against the tests that reach it, and the report records which tests those are.

After Stryker, `tools/Test-MutationReport.ps1` checks the report against one rule: a test may only kill a mutant it ran against. A kill by any other test means that test fails whatever is mutated, so the score is false.

Assessment:
- **Trade-offs:** TST-004's score is checked for real, and a false score is refused. No app needs a config file or a package; the kit owns the version and the settings. A run takes minutes, which is why it runs nightly rather than on every pull request.
- **Reversibility:** easy. It's one workflow, two kit files and one caller per repo.
- **Risk:** low to medium. The MTP runner is a preview.

### Option 2: Run it on every pull request as a required check

- **Trade-offs:** a surviving mutant would block the merge that introduced it. But every pull request would wait for the mutation run, and making it required is a ruleset change, which is the owner's call.
- **Reversibility:** easy, but the ruleset change needs the owner.
- **Risk:** slow pull requests, and a preview runner deciding merges.

### Option 3: Mutate only Domain and Application

- **Trade-offs:** faster and the most meaningful code. But the API's behaviour (status codes, paging, error formats) would never be mutation-tested, and TST-004 sets one score for the app.
- **Reversibility:** easy: a `mutate` filter.
- **Risk:** low, but it leaves the gap half open.

## Recommendation

Option 1: it enforces TST-004 as written, for the kit and every app, without slowing pull requests.

## Decision

Accepted, in auto mode (ADR-0035). Stryker.NET is the tool TST-005 names. The owner can reverse it, as with any merged change.

## Consequences

- **Workflows:** `.github/workflows/mutation.reusable.yml`, `.github/workflows/mutation.yml` (the kit) and `templates/app/.github/workflows/mutation.yml` (every new app). Not a required check: a low score shows as a failed nightly run on the Actions tab. `New-KitApp`'s required checks count only workflows that run on pull requests. Both shared .NET workflows count a solution's projects with `tools/Get-SolutionProjectCount.ps1`, and skip their .NET steps while it's empty.
- **The report:** each run uploads the HTML and JSON report for 14 days. It lists every surviving mutant, with its line and change.
- **API tests under Stryker, and the false 100% it caused:**
  - **The cause:** `WebApplicationFactory` finds the API's folder through `MvcTestingAppManifest.json`, keyed by the API assembly's full name. Stryker compiles from a design-time build, and MinVer (SUP-006) skips design-time builds, so Stryker's API had version `1.0.0.0` where the manifest says `0.0.0.0`. With no match, the factory fell back to "solution folder + project name", a folder that doesn't exist, and the API never started. Coverage capture then failed: the first run on PR 23 showed the API as "not covered" (28.81%). Running every test against every mutant turned the same failures into kills, a false 100%.
  - **The fix:** the sample's `ApiFactory` sets the content root itself, relative to the solution file (`UseSolutionRelativeContentRoot`). `ContentRootTests` points the content root at a missing folder first, as the factory's fallback does, and checks the API still starts. Every app uses MinVer and `WebApplicationFactory`, so an app's API tests do the same (`docs/standards/testing.md`).
  - **Ruled out:** Stryker's `break-on-initial-test-failure` doesn't catch it, because the initial run uses the normal build, whose version matches. Per-test coverage doesn't either: when coverage capture fails, Stryker falls back to running every test.
- **A false score is refused:** `Test-MutationReport.ps1` fails the run when a test killed a mutant it never reached. A static mutant (code that runs once) runs against every test, so it's exempt. On PR 23's false report it names 65 tests; on the healthy report it finds nothing.
- **The sample:** its first real runs found gaps, now closed by tests:
  - a null URL and a null request failed late with a `NullReferenceException`;
  - the URL error message wasn't asserted;
  - nothing checked the database model's key, required fields, title length or URL index;
  - nothing checked the logging options, or that `/alive` ignores a failing readiness check.

  It now scores 94.34%, locally and in CI. The six survivors left can't change behaviour, or barely can: two database model lines EF already infers, a null guard repeated in the next call, two endpoint names, and one exception message.
- **Rules:** TST-004 and TST-003 now name the workflow as their enforcement. GAP-003 is closed.
- **Running it locally:** it's optional; the CI report gives the same detail. In the kit, `dotnet tool restore` installs the pinned Stryker (installing is the owner's call), then `dotnet tool run dotnet-stryker --config-file .config/stryker-config.json --solution dotnet-agent-kit.slnx` runs it with CI's settings (AGENTS.md, Commands).

## Pillars affected

- **Reliability:** tests are checked for whether they'd notice a wrong change, not just whether code ran, and a false score fails the run.
- **Operational Excellence:** one shared workflow, one version and one settings file, with a report to read when a night fails.
- **Cost Optimization:** free on public repos' standard runners; nightly keeps it off the pull request path.
- **Security:** the job has a read-only token, and Stryker is pinned to an exact version that Dependabot updates.
- **Performance Efficiency:** n/a for the apps themselves.

## Sources

- https://stryker-mutator.io/docs/stryker-net/configuration/, retrieved 2026-11-08
- https://github.com/stryker-mutator/stryker-net/releases, retrieved 2026-11-08 (5.0.0: .NET 10 runtime, MTP per-test coverage)
- https://api.nuget.org/v3-flatcontainer/dotnet-stryker/index.json, retrieved 2026-11-08 (5.0.0 is the latest)
- https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests, retrieved 2026-11-08 (how WebApplicationFactory infers the content root)
- https://github.com/dotnet/aspnetcore/blob/main/src/Mvc/Mvc.Testing/src/WebApplicationFactory.cs, retrieved 2026-11-08 (the manifest lookup and its fallback)
- ADR-0003 and TST-005 (Stryker in the kit's test toolset), TST-004 (the 85% score), SUP-006 (MinVer)
