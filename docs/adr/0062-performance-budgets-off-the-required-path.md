# ADR-0062: Performance budgets, checked off the required path

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

Scorecard GAP-012 says no app has benchmarks, performance budgets for its hot paths, or load tests. ADR-0003 names BenchmarkDotNet for benchmarks, and ADR-0057 chose Locust, run in GitHub Actions, for load tests. The new-app intake (ADR-0058, `templates/app-intake.json`) offers both. Nothing runs either yet.

A budget is only worth having if something checks it. The kit's checks run on GitHub's shared runners. Their speed varies from run to run, because other jobs share the hardware. A time limit tight enough to catch a real regression on such a runner also fails some runs where nothing changed. A required check that fails at random teaches people to rerun it until it passes.

Not every measure is noisy. The bytes a .NET method allocates per call are the same on every run of the same code and runtime. Time and latency vary.

Microsoft's guidance is to load test a Release build in the Production environment, never Debug or Development, which log more ("ASP.NET Core load/stress testing"). A kit app's endpoints need a bearer token (SEC-007). Microsoft names `dotnet user-jwts`, in the .NET SDK, for issuing test tokens ("Manage JSON Web Tokens in development with dotnet user-jwts").

## Options

### Option 1: Budgets as a required check on every pull request

Benchmarks and the load test run on every pull request, and a result over budget blocks the merge.

- **Trade-offs:** Catches a regression before it merges. On a shared runner, a tight time budget flakes and a loose one catches little, so the check would need reruns or limits too loose to mean much.
- **Reversibility:** Easy.
- **Risk:** High: a flaky required check blocks every pull request and gets rerun until it passes.

### Option 2: Compare each run with a stored baseline

A tool such as the "Continuous Benchmark" GitHub Action stores each run's results, for example on a GitHub Pages branch, and fails when a result is a set percentage worse than the stored one. Microsoft's MSAL.NET does this.

- **Trade-offs:** No absolute numbers to choose, and a history to read. It needs write access to store results, another third-party action, and a branch of data. The baseline comes from the same noisy runners, so the percentage still has to allow for noise.
- **Reversibility:** Moderate: the stored history is lost if it's dropped.
- **Risk:** Medium: write permission in a workflow that runs pull-request code.

### Option 3: Absolute budgets in the repo, off the required path

Each benchmarks project keeps a `benchmark-budget.json`: for each benchmark, a maximum mean time and a maximum of bytes allocated per operation. Each load test keeps a `load-budget.json`: response-time percentiles and a maximum share of failed requests, for the whole run and for any request it names. Two kit scripts check them: `Test-BenchmarkBudget.ps1` and `Test-LoadBudget.ps1`.

- **Allocation budgets:** exact, because allocations don't vary.
- **Time and latency budgets:** ceilings with room for the runner, set at about twice what the runner measured, and a load test's percentiles no lower than 100 ms, since one pause on a shared runner costs tens of milliseconds. The measured numbers are in the run's artifact.
- **When it runs:** a shared workflow, `performance.reusable.yml`, nightly and on demand in apps. In the kit it also runs on every pull request. It's never a required check.
- **Trade-offs:** Simple, no stored state, nothing to write. A slower change can merge before the nightly run shows it, unless its pull request runs the workflow (the kit's does). The budgets are numbers someone has to choose and update.
- **Reversibility:** Easy.
- **Risk:** Low.

### Option 4: A dedicated or self-hosted runner

The same budgets, run on hardware that nothing else shares.

- **Trade-offs:** Steadier numbers, so tighter limits. It costs money: a larger GitHub-hosted runner is billed per minute, and a self-hosted one is a machine to buy, run and secure. It also needs the owner's OK (SEC-003).
- **Reversibility:** Easy.
- **Risk:** Medium: a self-hosted runner on a public repo can run anyone's pull-request code.

## Recommendation

Option 3. It checks a budget on every run without a flaky gate. Allocations, which don't vary, get an exact budget, and time gets room for the shared runner. It needs no stored state and no write permission. Option 2 or 4 can come later if the numbers show the need, and Option 4 would be listed with its price.

## Decision

Option 3, decided in auto mode (ADR-0035) on 2026-11-12, at the owner's request (scorecard GAP-012). The owner approved three parts of it on 2026-11-12, because they narrow CI checks or add a dependency no kit rule names: the coverage gate leaves out benchmarks projects ("Yes, skip them"), the SBOM leaves them out, and the load job uses `actions/setup-python` ("Yes to both").

- **Benchmarks projects.** A project whose name ends in `.Benchmarks`, under `tests/`, is a BenchmarkDotNet console app. `sample/Directory.Build.props`, which an app gets as `tests/Directory.Build.props`, makes it an Exe and references BenchmarkDotNet. It isn't a test project, so `dotnet test` leaves it alone. The same name is how three other places know it: the coverage gate and the SBOM's solution filter leave it out, as test-side code that ships nothing, and the workflow runs it. **Update (2026-11-12):** the name rule has one source, `Test-BenchmarksProject` in `tools/KitSolution.psm1` (CRF-003). Those three call it; `tests/Directory.Build.props` and `.editorconfig`, which can't, are checked against it by `tools/tests/KitSolution.Tests.ps1`, which also fails if a kit script or workflow writes the rule again.
- **CA1515 off in benchmarks projects only.** BenchmarkDotNet runs only public, unsealed benchmark classes. CA1515 asks an Exe to make its public types internal. So `.editorconfig` turns CA1515 off in `*.Benchmarks` folders only (STY-006 needs this ADR).
- **The load test runs the app as production would.** It starts the app the caller names, built in Release, in Production, on the URL Locust loads, and waits for `/health`. Locust runs headless from the load test's folder, so its `locust.conf` sets the load. Only the budget decides the result: Locust is run with `--exit-code-on-error 0`, and `Test-LoadBudget.ps1` also fails on an exception in the locustfile.
- **The token, when the app needs one.** With `load-test-user-jwt: true`, the job issues a token with `dotnet user-jwts`. The app runs in Production, which doesn't read user secrets. So the job hands the app user-jwts' signing key, issuer and audience through environment variables, masked, for that job only.
- **Locust is pinned with every package it pulls in.** `.config/locust/requirements.txt` is pip-compile's output, with every version pinned by hash, and is installed with `--require-hashes`. `.python-version` beside it names the Python it was compiled for, and the workflow sets that Python up with `actions/setup-python`. Dependabot's pip updater watches the folder, with the same 7- and 14-day waits as the other entries (ADR-0041).
- **A red run.** An agent treats a red performance run on its pull request as a finding to answer before merging. Either the change is fixed, or the budget changes with the reason in the pull request. A runtime or SDK update can move allocations too, so its pull request may need the same.

## Consequences

- `tools/Test-BenchmarkBudget.ps1`, `tools/Test-LoadBudget.ps1` and their tests. Apps get both in `.kit/tools`.
- `.github/workflows/performance.reusable.yml`, the kit's `performance.yml` (nightly, on demand, every pull request), and the app template's `performance.yml` (nightly and on demand). The app owns that file, so the kit's sync never changes it: an app adds the load test's inputs there when it has an HTTP endpoint, and Dependabot moves its kit pin.
- The sample has `sample/tests/Bookmarks.Benchmarks`, which benchmarks `Bookmark.Create`, and `sample/tests/load`, a Locust test of the bookmarks API. Both prove the workflow in CI. The load test measures the API and its SQLite file on a shared runner, not a deployment. A release-level load test of a deployed app waits for a deployment pipeline (GAP-015).
- The coverage gate, the SBOM (SUP-009) and `.editorconfig` each leave out `*.Benchmarks` projects. The owner approved the coverage gate and SBOM changes on 2026-11-12, because they narrow CI checks. A benchmarks project is test-side code: it measures production code, ships nothing, and no test loads it, so the gate would otherwise fail it as untested, and the SBOM would list packages that never ship.
- New dependencies:
  - BenchmarkDotNet 0.15.8 (MIT; ADR-0003). It's a 0.x package, so its updates are the owner's to merge (ADR-0041).
  - Locust 2.47.0 (MIT; ADR-0057) and its packages. Pip updates are the owner's to merge.
  - `actions/setup-python` v7.1.0 (GitHub's own; MIT), pinned by SHA, approved by the owner on 2026-11-12.
- Locust's packages are resolved for Linux and Python 3.12, where CI runs them. On another system a person installs Locust their own way. Nothing moves the Python version, so a Locust release that drops 3.12 needs `.python-version` raised and the file compiled again. An app's locustfile can't add Python packages of its own.
- The intake offers JMeter and Azure Load Testing beside Locust. The workflow runs only Locust. An app that chooses another tool runs it its own way until the kit supports it.
- TST-009 (proposed) states the rule. Scorecard GAP-012 is closed.

## Pillars affected

- **Performance Efficiency:** hot paths and endpoints get budgets that something checks.
- **Reliability:** no flaky required check; a missing, renamed or failed benchmark or request fails instead of passing silently.
- **Security:** the load-test token and key exist only on the runner and are masked; the app runs in Production; Locust installs only hash-checked packages.
- **Cost Optimization:** GitHub-hosted runners, free on a public repo; a private app uses its Actions minutes for one short run a night.
- **Operational Excellence:** every run uploads its reports, Locust's stats and the app's log.

## Sources

- owner, 2026-11-11 (Locust by default, ADR-0057)
- owner, 2026-11-12 (the coverage gate and the SBOM leave out benchmarks projects; actions/setup-python)
- https://learn.microsoft.com/aspnet/core/test/load-tests?view=aspnetcore-10.0, retrieved 2026-11-12
- https://learn.microsoft.com/aspnet/core/security/authentication/jwt-authn?view=aspnetcore-10.0, retrieved 2026-11-12
- https://learn.microsoft.com/entra/msal/dotnet/advanced/performance-testing, retrieved 2026-11-12
- https://learn.microsoft.com/ef/core/performance/performance-diagnosis#benchmarking-with-ef-core, retrieved 2026-11-12
- https://learn.microsoft.com/azure/well-architected/performance-efficiency/performance-test, retrieved 2026-11-12
- https://benchmarkdotnet.org/articles/guides/console-args.html, retrieved 2026-11-12
- https://docs.locust.io/en/stable/configuration.html, retrieved 2026-11-12
- https://github.com/locustio/locust/blob/2.47.0/locust/stats.py, retrieved 2026-11-12
- https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories, retrieved 2026-11-12
