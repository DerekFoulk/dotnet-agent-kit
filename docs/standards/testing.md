---
topic: testing
rules:
  - id: TST-001
    statement: "Write the test first: commit it failing on an assertion (red), then commit the change that makes the full suite pass (green), then refactor on green."
    why: "The owner is \"a true believer in TDD\"; a test seen failing for the right reason proves it tests something."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-10-26", "ADR-0018"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: kit-checks.reusable.yml runs tools/Test-RedGreenOrder.ps1, which checks the order of commits marked red or green"
      - kind: gate
        in: [app]
        how: "ci: app-checks.reusable.yml runs tools/Test-RedGreenOrder.ps1 the same way"
      - kind: advisory
        in: [kit, app]
        how: "a change committed with no marker, and a red that crashed instead of failing an assertion, still pass, so test-first itself is advisory"
    scope: core
    paths: ["**"]
  - id: TST-002
    statement: "Every plan includes a test list; turn one item at a time into a failing test, never the whole list up front."
    why: "Canon TDD: converting the whole list first locks in early design choices that later tests show were wrong."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0018"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the start-work and plan-checklist skills require a test list, and start-work's plan review checks the plan has one before any code; no tool can judge a plan"
    scope: core
    paths: ["**"]
  - id: TST-003
    statement: "Each part of an app gets the test kinds in the brief's test matrix (unit, integration, functional, UI, architecture, contract, mutation), in one test project per production project plus the shared IntegrationTests, FunctionalTests, E2E.Tests and Architecture.Tests projects."
    why: "The owner wants complete coverage of all test types, to the extent that is best practice."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-10-25", "owner, 2026-10-26", "owner, 2026-11-11", "ADR-0058"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the sample's unit, integration, functional, contract and architecture test projects, and the web UI fixture's E2E tests (fixtures/WebUi), run in dotnet-ci.reusable.yml, which installs Playwright's browser first for any project that uses it (ADR-0061); mutation testing runs nightly in mutation.reusable.yml (ADR-0039)"
      - kind: advisory
        in: [kit, app]
        how: "the rest: UI tests apply only to apps with a UI, and a production project without its own test project (the sample's Contracts, Infrastructure, Api) is covered by the shared IntegrationTests and FunctionalTests"
      - kind: advisory
        in: [app]
        how: "the matrix itself: the shared .NET CI runs the test projects an app has, but nothing notices one it lacks. A check that fails the build when a production project lacks the test projects the matrix requires is planned (GAP-027); it waits for ARC-009, which settles which projects an app has"
    scope: core
    paths: ["**/*.csproj", "**/*Tests*/**"]
  - id: TST-004
    statement: "Coverage gates: 100% line coverage for pure domain assemblies, 95% for application assemblies, 90% overall; mutation score 85% (nightly)."
    why: "Thresholds approved in one project's plan, then ratified as kit defaults. Microsoft warns that a high coverage goal can be counterproductive; the kit keeps these on purpose, as the owner's full rigor (brief §2), and the mutation score checks that the tests catch wrong code, not just run it."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-04", "ADR-0039", "owner, 2026-11-12", "https://learn.microsoft.com/dotnet/core/testing/unit-testing-best-practices, retrieved 2026-11-13"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: tools/Test-CoverageGate.ps1 in dotnet-ci.reusable.yml fails a build below the line-coverage minimums, leaving out test and benchmarks projects (tools/tests/Test-CoverageGate.Tests.ps1, ADR-0062)"
      - kind: advisory
        in: [kit, app]
        how: "mutation.reusable.yml runs Stryker.NET nightly and fails below a mutation score of 85% (ADR-0039, tools/tests/MutationCi.Tests.ps1); it isn't a required check, so a low score shows as a failed nightly run, not a blocked pull request"
    scope: core
    paths: ["**/*Tests*/**"]
  - id: TST-005
    statement: "Use the kit's test toolset, the tools templates/app-intake.json lists for each test type (TST-007 keeps that list); a different tool needs an ADR."
    why: "One toolset the owner chose, listed in one place; FluentAssertions is swapped for AwesomeAssertions in commercial repos (ADR-0004), and Locust is the free default for load tests (ADR-0057)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0003", "ADR-0057", "ADR-0058"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "no check stops a project from adding another test package; central package management keeps versions in one reviewed file, where code review checks for the ADR. (tools/tests/KitIntake.Tests.ps1 checks the intake list is complete, which is TST-007's gate, not this rule's)"
    scope: core
    paths: ["Directory.Packages.props", "**/*.csproj"]
  - id: TST-006
    statement: "Every kit script and check has Pester tests, written first."
    why: "Scripts are code; the owner's test-first rule applies to them too."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "ADR-0011"]
    enforcement:
      - kind: advisory
        in: [kit]
        how: "CI runs every Pester test (kit-checks.reusable.yml), but no check shows that each script has tests or that they were written first"
    scope: core
    paths: ["tools/**"]
  - id: TST-007
    statement: "The kit's list of test tools lives only in templates/app-intake.json: each kind of test, its tools, each tool's license and its cost label (Free, Free tier or Paid, with the price, its source and the date checked unless Free); every default is Free, or free for a non-commercial app (FluentAssertions 8, ADR-0004), and anything else that names test tools is checked against it or points to it."
    why: "One source for the tools the new-app intake offers and the standard names (CRF-003); the owner wants paid options listed with their price beside a free default."
    layer: owner
    basis: preference
    status: proposed
    sources: ["owner, 2026-11-11", "ADR-0058"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "check: tools/tests/KitIntake.Tests.ps1 fails when a tool TST-005 or ADR-0003 names is missing from the list, when a tool has no license or cost label, when a non-Free one has no price, source or date, or when a default is neither Free nor free for a non-commercial app"
    scope: core
    paths: ["templates/app-intake.json", "docs/standards/testing.md"]
  - id: TST-008
    statement: "A check fails an app's build when a production project lacks the test projects TST-003's matrix requires for it."
    why: "TST-003 is advisory for apps: nothing notices a project without its tests until code review does. Retired 2026-11-13: the planned check is TST-003's enforcement, not a rule of its own (rules audit, D6)."
    layer: owner
    basis: preference
    status: retired
    sources: ["owner, 2026-11-11", "ADR-0058"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "not built yet; it waits for ARC-009, which settles which projects an app has, to be accepted (scorecard GAP-027)"
    scope: core
    paths: ["**/*.csproj", "**/*Tests*/**"]
  - id: TST-009
    statement: "Each hot path gets a benchmark, and each app with an HTTP endpoint a load test, each with a budget kept beside it (benchmark-budget.json, load-budget.json) and checked by the kit's shared performance workflow; the tools are the intake's defaults for the performance and load kinds of test (TST-007)."
    why: "A budget is a requirement only when something checks it; shared runners vary, so the check runs off the required path, with exact allocation budgets and time budgets that leave room for the runner (ADR-0062)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["owner, 2026-11-11", "ADR-0057", "ADR-0062"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "performance.reusable.yml runs every *.Benchmarks project and the load test the caller names, and fails over budget through tools/Test-BenchmarkBudget.ps1 and tools/Test-LoadBudget.ps1 (tools/tests/Performance.Tests.ps1 and both scripts' tests), nightly and on demand, and on every kit pull request; it's never a required check, so a red run is a finding to answer, not a blocked merge (ADR-0062)"
      - kind: advisory
        in: [kit, app]
        how: "which paths are hot and whether an app has its load test"
    scope: core
    paths: ["**/*.Benchmarks/**", "**/tests/load/**", "**/benchmark-budget.json", "**/load-budget.json"]
---

# Testing

Test-first at every level (ADR-0018). The test matrix in brief §6.7 sets which kinds of test each part of an app gets. "Acceptance test" names a purpose, not a kind of test: a test written from a requirement, usually at the functional or UI level. It's tagged with its requirement rather than given its own folder.

## Test tools

`templates/app-intake.json` lists each kind of test (the brief's matrix, plus load tests) with what it checks, when it runs, and its tools, each with its license and its cost label: Free, Free tier or Paid, with the price, its source and the date it was checked (TST-007, ADR-0058). The defaults are free: FluentAssertions 8 is free only for a non-commercial app, and a commercial one swaps it for AwesomeAssertions (ADR-0004). Paid tools stay on the list, labelled. The new-app skill shows this list on its test tools card, and each app records its choice in `docs/app-profile.md`. Load tests run Locust by default, in GitHub Actions; JMeter suits heavy database or queue load, and Azure Load Testing and NBomber are paid (ADR-0057).

## Coverage

`dotnet test --coverage --coverage-output-format cobertura --results-directory <dir>` writes one Cobertura report per test project (Microsoft.Testing.Extensions.CodeCoverage, on Microsoft Testing Platform via `global.json`). `./tools/Test-CoverageGate.ps1 -Path <dir>` merges them and applies TST-004. It leaves out test assemblies, benchmarks assemblies (`*.Benchmarks`, ADR-0062) and generated files (`*.g.cs`, `*.generated.cs`, anything under `obj/`), and it fails when it finds no report. Given the solution, it also fails for any production project no test loads, except a UI project (a MAUI or desktop project, found by `tools/Get-UiProject.ps1`), which it exempts and names: its logic lives in libraries the gate counts (ARC-010, ADR-0059).

## Mutation testing

`.github/workflows/mutation.yml` runs Stryker.NET nightly with the kit's `.config/stryker-config.json` and fails below a mutation score of 85% (TST-004, ADR-0039). Then `Test-MutationReport.ps1` checks that every kill came from a test that reached the mutant, so a test that fails whatever is mutated can't fake a high score. Each run that gets as far as a report uploads it as a `mutation-report` artifact, which lists each surviving mutant.

An app needs no Stryker install, config file or tool manifest of its own: the shared workflow reads the version and settings from the kit at its pinned commit. The report artifact shows each survivor's line and change, which is what a local run would show, so apps get no local setup until one is needed (YAGNI). The kit itself has a tool manifest for working on the kit's own settings (the kit's [AGENTS.md](https://github.com/DerekFoulk/dotnet-agent-kit/blob/main/AGENTS.md#commands), Commands).

**API tests set the API's content root themselves.** `WebApplicationFactory` looks the API's folder up in `MvcTestingAppManifest.json` by the API assembly's full name. Stryker compiles from a design-time build, which MinVer (SUP-006) skips, so Stryker's API has a different version, the lookup fails, and every API test fails under Stryker. Give the app's factory a `ConfigureWebHost` override that calls `builder.UseSolutionRelativeContentRoot(...)` with the API project's path from the solution folder, and a test that the API still starts when the content root it's given is wrong. The kit's sample does both: [`ApiFactory.cs`](https://github.com/DerekFoulk/dotnet-agent-kit/blob/main/sample/tests/Bookmarks.FunctionalTests/ApiFactory.cs) and [`ContentRootTests.cs`](https://github.com/DerekFoulk/dotnet-agent-kit/blob/main/sample/tests/Bookmarks.FunctionalTests/ContentRootTests.cs).

## Browser and accessibility tests

An app with a web UI (Blazor, Razor) tests it in a real browser from its `E2E.Tests` project (TST-003), with Playwright for .NET and Deque's axe for Playwright (ADR-0003, ADR-0061). Every page gets a test that opens it, checks it loaded and runs axe's WCAG 2.2 level A and AA rules (UI-002); `docs/standards/ui.md` says what axe checks and what stays with a person. The kit's web UI fixture, [`fixtures/WebUi`](https://github.com/DerekFoulk/dotnet-agent-kit/tree/main/fixtures/WebUi), is the pattern to copy:

- **Hosting:** the test project references the web project and hosts it with `WebApplicationFactory` on Kestrel, so a browser can reach it: `UseKestrel(0)` in the factory's constructor, then `StartServer()`, and the address from `ClientOptions.BaseAddress` (.NET 10). Port 0 lets the system pick a free port: Kestrel's default, 5000, would clash when two factories run at once, as test classes, test projects and Stryker's runners do. Like the sample's API factory, it sets the content root relative to the solution, and a test checks the app still starts when the factory's own lookup goes wrong (see "Mutation testing" above). An app with an Aspire AppHost can start the whole app with Aspire testing instead (`templates/app-intake.json`).
- **One browser per test:** each test starts the app, a headless Chromium and a fresh browser context, and disposes them, so no test sees another's cookies or focus. That costs about a second a test; xUnit needs public test classes, and a shared fixture type they take in their constructor would have to be public too, which CA1515 rejects in a test project.
- **Waiting:** Playwright's `Expect(...)` assertions and locators wait for the page by themselves; never sleep.
- **Pages behind sign-in:** the factory signs the browser in with a test authentication scheme, as Microsoft's "Integration tests in ASP.NET Core" page shows, never through the real identity provider.
- **Components:** a Razor component with logic of its own gets bUnit tests (the intake's Functional kind), which run in milliseconds and need no browser; Microsoft's "Test Razor components" page says which to use when. The fixture has no such component, so it has no bUnit project. Keep logic in `.razor.cs` files or plain classes rather than `@code` blocks: the code shape and duplicate code checks and Stryker don't read code in `.razor` files (`docs/standards/craft.md`).
- **Interactive render modes** aren't covered yet (GAP-036): the fixture is static server rendering with enhanced navigation.

**In CI.** `dotnet-ci.reusable.yml` runs the E2E tests in its "Test with coverage" step, in the required job. Just before, its "Playwright browser" step runs `tools/Install-PlaywrightBrowser.ps1`. For each project whose restore graph holds Microsoft.Playwright, it runs the `playwright.ps1` the build put beside the test assembly: `install --with-deps chromium`, once per Playwright version. Without such a project it does nothing. The Chromium build is the one the Microsoft.Playwright version pins, so Dependabot moves it with the package. Playwright's installer checks no hash of what it downloads (GAP-033). The nightly mutation run builds and installs the same way before Stryker.

**On your machine.** The tests need the Chromium build the Microsoft.Playwright version pins. Installing it is the owner's step ("Always ask" in AGENTS.md): after a build, `pwsh tests/<App>.E2E.Tests/bin/Debug/net10.0/playwright.ps1 install chromium` (the target framework folder is the project's). Without it, the tests fail with Playwright's own message naming that command. On Windows, clone into a short folder, such as `C:\src\<repo>`. Playwright's build copies files nested more than 90 characters deep into each E2E project's build output. From a clone whose deepest output path was 286 characters, Microsoft's coverage collector wrote an empty report for the E2E project, without a warning, and the coverage gate then failed the web project as one no test loads; the same commit cloned into a short folder was counted, and one whose deepest path was 263 characters was counted too. To check, find the longest path under the E2E project's `bin` folder. The gate names each empty report (the collector names them by a GUID, not by project) and points here. CI runs the tests on Linux, where no report has come back empty.

## Performance and load tests

TST-009, ADR-0062. Both check a budget kept in the repo, and both run in `.github/workflows/performance.reusable.yml`: nightly and on demand in an app, and also on every pull request in the kit. Shared runners vary from run to run, so it's never a required check. A red run on a pull request is a finding to answer before merging: fix the change, or change the budget and give the reason in the pull request.

**Benchmarks.** A benchmarks project is `tests/<App>.Benchmarks`. `tests/Directory.Build.props` makes it a BenchmarkDotNet console app; it isn't a test project. Its `Program.cs` calls `BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args)`, and each benchmark class is public, unsealed and marked `[MemoryDiagnoser]`. Beside it, `benchmark-budget.json` gives each benchmark, by its full name, a `maxMeanNanoseconds` and a `maxAllocatedBytes`. Allocations don't vary, so set that budget to what the benchmark allocates. Time varies, so set it to about twice the mean the CI run measured: read it in the run's `benchmark-results` artifact (the sample's `Bookmark.Create`: 842.5 ns on the runner, so 1,700). `Test-BenchmarkBudget.ps1` fails a benchmark over budget, one without a budget or without a result, a budget with no benchmark, and a report without allocations. The kit's sample benchmarks `Bookmark.Create` (`sample/tests/Bookmarks.Benchmarks`).

**Load tests.** A load test is `tests/load/`. `locustfile.py` describes what users do; `locust.conf` sets how many users, how fast they start and how long the run lasts; `load-budget.json` sets the limits. Its `"Aggregated"` entry, the whole run, needs a `maxFailureRatio`. It and any request Locust names (`"<Type> <Name>"`, such as `"GET /bookmarks/[id]"`; give a request with an id in its URL a `name=`) can set `maxMilliseconds` for any of Locust's percentiles, such as `"95%"`. Set them to about twice what the run's `load-test-results` artifact shows, and no lower than 100 ms: one pause on a shared runner costs tens of milliseconds (the sample's 95th percentile was 4 ms, its 99th 8 ms, and the slowest request 540 ms). The workflow starts the app the caller names in `load-test-project`, built in Release, in Production, on `load-test-url`, and waits for `/health`. With `load-test-user-jwt: true` it issues a token with `dotnet user-jwts` and hands it to the locustfile as `LOAD_TEST_TOKEN`. `Test-LoadBudget.ps1` fails a percentile or failure ratio over budget, a run or budgeted request with no requests, and any exception in the locustfile. The numbers measure the app on a shared runner; a load test of a deployed app waits for a deployment pipeline (GAP-015). The kit's sample load tests the bookmarks API (`sample/tests/load`).

Locust is pinned with every package it pulls in, by hash, in the kit's `.config/locust/requirements.txt`, for Linux and the Python in `.config/locust/.python-version`, where CI runs it. To run a load test locally, install Locust your own way. An app's locustfile can't add Python packages of its own.

## Script tests

A Pester test file that makes git repos imports `tools/tests/TestGit.psm1`. It calls `Set-TestGitEnvironment` in its `BeforeAll` and `Restore-TestGitEnvironment` in its `AfterAll`, and makes any bare repo it pushes into with `New-TestGitRemote`. Nothing git reads from the machine reaches a test repo:
- **Inherited git variables:** every `GIT_*` variable is removed while tests run (`GIT_CONFIG`, `GIT_DIR`, `GIT_DEFAULT_HASH`, config handed down from a parent git, and the rest). Only `GIT_TRACE*` stays, since it records what git does without changing it.
- **Config, ignore and attributes files:** no global or system config (`GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM`), no system attributes (`GIT_ATTR_NOSYSTEM`), and the default per-user ignore and attributes files replaced by an empty one (`core.excludesFile`, `core.attributesFile`).
- **Templates:** `GIT_TEMPLATE_DIR` points at an empty directory of the run's own, which Restore removes. It's private to your account: 0700 off Windows, and on Windows as private as your own `%TEMP%`.

So a global hook, a team template, or a `.vscode/` line in `~/.config/git/ignore` can't change a test. Every repo commits as the fixture and unsigned, through git's `GIT_AUTHOR_*` and `GIT_COMMITTER_*` variables and its `GIT_CONFIG_COUNT` settings, which outrank a repo's own config too. git also starts no background maintenance and no file-system monitor. One consequence: a `safe.directory` entry in your global or system config doesn't apply either, so run the tests from a checkout your own account owns. The tests list the checkout's own files before switching this on, so your global ignore rules still apply to them; only `Test-RepoGitIgnore`, below, reads the checkout with the test settings on. A repack started by a fixture commit once raced a test's next lookups and failed 11 tests, but only for some file contents. `TestGit.Tests.ps1` fails when a file that makes repos doesn't use the helper, or makes a bare remote by hand. A test that runs a script or a hook against a repo runs it in a repo it made, passing that repo's path or starting the process there, never in the directory the tests run from. Only the tests that check the kit's own files read the checkout, and only for its files. The commit-msg hook skips a merge in progress in the repo it runs in, so once, run from a kit checkout mid-merge, the hook let a bad subject through and its rejection tests failed. No check enforces that rule. A test that checks a file stays out of commits uses `Test-RepoGitIgnore`, which judges the root `.gitignore` on its own: a line in your clone's `.git/info/exclude` would otherwise hide one missing from it. It stops if the repo commits a `.gitignore` below the root (one not yet added to git isn't seen), which could un-ignore the file. `TestGit.Tests.ps1` fails when a test file runs `git check-ignore` itself; other ways of reading ignore rules, such as `git status --ignored`, aren't checked.
