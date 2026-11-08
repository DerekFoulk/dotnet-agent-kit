# ADR-0039: Run mutation testing nightly with Stryker.NET, through a shared workflow

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

TST-004 asks for a mutation score of at least 85%, checked nightly. Until now nothing ran it, so that part of the rule was advisory (scorecard GAP-003).

Mutation testing changes the code in small ways, called mutants: a `>` becomes `>=`, a guard is removed, a string is emptied. Then it runs the tests against each mutant. A mutant the tests don't notice "survived". The mutation score is the share of mutants the tests killed. Line coverage only says code ran; the mutation score says the tests would notice if it were wrong.

TST-005 already names Stryker.NET as the kit's mutation tool. Stryker.NET 5.0.0 (11 September 2026) targets .NET 10 and has a Microsoft Testing Platform runner (`--test-runner mtp`, marked preview), which the kit's xUnit v3 test projects need. Its documentation doesn't mention `.slnx` solutions.

This ADR was decided in auto mode (ADR-0035).

## Options

### Option 1: A shared nightly workflow for the kit and every app

`mutation.reusable.yml` installs Stryker.NET at a pinned version for the run only, mutates the whole solution with the MTP runner, and fails below 85% (`--break-at 85`). The kit calls it nightly, on demand, and on a pull request that changes the sample or the mutation setup. Every new app gets a nightly caller from `templates/app`.

Two settings that have no command-line flag go in a config file the workflow writes:
- **`coverage-analysis: off`:** every test runs against every mutant. With Stryker's default per-test coverage, the first run on PR 23 reported every mutant in the API, `Program.cs` and the service defaults as "not covered", although the functional tests exercise all of them through an in-memory host. The sample scored 28.81%.
- **`ignore-methods: ConfigureAwait`:** `ConfigureAwait(true)` can't change behaviour without a synchronization context, so no test could ever kill that mutant.

Assessment:
- **Trade-offs:** TST-004's score is checked for real. No app needs a config file or a package; the kit owns the version and the threshold. Running every test against every mutant is slower, which is why it runs nightly rather than on every pull request.
- **Reversibility:** easy. It's one workflow and one caller per repo.
- **Risk:** medium. The MTP runner is a preview, and the Stryker version is pinned in the workflow, where Dependabot doesn't see it. So the kit updates it by hand, as it does the gitleaks image (ADR-0024).

### Option 2: Run it on every pull request as a required check

- **Trade-offs:** a surviving mutant would block the merge that introduced it. But every pull request would wait for every test to run against every mutant. Making it required is also a ruleset change, which is the owner's call.
- **Reversibility:** easy, but the ruleset change needs the owner.
- **Risk:** slow pull requests, and a preview runner deciding merges.

### Option 3: Mutate only Domain and Application

- **Trade-offs:** faster and the most meaningful code. But the API's behaviour (status codes, paging, error formats) would never be mutation-tested, and TST-004 sets one score for the app.
- **Reversibility:** easy: a `mutate` filter.
- **Risk:** low, but it leaves the gap half open.

## Recommendation

Option 1: it enforces TST-004 as written, for the kit and every app, without slowing pull requests.

## Decision

Accepted, in auto mode (ADR-0035). Stryker.NET is the tool TST-005 names, installed in CI only. The owner can reverse it, as with any merged change.

## Consequences

- **Workflows:** `.github/workflows/mutation.reusable.yml`, `.github/workflows/mutation.yml` (the kit), and `templates/app/.github/workflows/mutation.yml` (every new app). Not a required check: a low score shows as a failed nightly run on the Actions tab. `New-KitApp`'s required checks count only workflows that run on pull requests.
- **The report:** each run uploads the HTML and JSON report for 14 days. It lists every surviving mutant, with its line and change.
- **The sample:** its first runs found real gaps, now closed by tests: a null URL and a null request failed late with a `NullReferenceException`; the URL error message wasn't asserted; and nothing checked the database model's key, required fields, title length or URL index. MEASURED_SCORE
- **Rules:** TST-004 and TST-003 now name the workflow as their enforcement. GAP-003 is closed.
- **Apps with no projects** skip the run, as the .NET CI does.
- **Not run locally:** running Stryker on your machine means installing a dotnet tool, which is the owner's call. The report from CI gives the same detail.

## Pillars affected

- **Reliability:** tests are checked for whether they'd notice a wrong change, not just whether code ran.
- **Operational Excellence:** one shared workflow, with a report to read when a night fails.
- **Cost Optimization:** free on public repos' standard runners; nightly keeps it off the pull request path.
- **Security:** the job has a read-only token, and Stryker is pinned to an exact version.
- **Performance Efficiency:** n/a for the apps themselves.

## Sources

- https://stryker-mutator.io/docs/stryker-net/configuration/, retrieved 2026-11-08
- https://github.com/stryker-mutator/stryker-net/releases, retrieved 2026-11-08 (5.0.0: .NET 10 runtime, MTP per-test coverage)
- https://api.nuget.org/v3-flatcontainer/dotnet-stryker/index.json, retrieved 2026-11-08 (5.0.0 is the latest)
- ADR-0003 and TST-005 (Stryker in the kit's test toolset), TST-004 (the 85% score)
