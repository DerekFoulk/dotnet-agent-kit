# ADR-0098: The sample's tests and load test run on SQL Server in a container

- **Status:** Proposed
- **Date:** 2026-11-25

## Context

GAP-025: the sample ran on SQLite with `EnsureCreated`, so nothing proved DAT-002 (EF Core migrations, never `EnsureCreated`, a test that fails on a model change no migration covers) or DAT-005 (tests on the production engine) end to end. ADR-0053 makes Azure SQL Database's free offer the guide's default for relational data, and ADR-0054 names `Testcontainers.MsSql` for the tests. The owner chose on 2026-11-25 to close the gap before v0.1.0.

Constraints:

- **Docker isn't always there.** CI's Linux runners have it, and the shared CI already runs every test project inside the Playwright image with the runner's Docker socket (`Invoke-WithPlaywrightImage.ps1`, ADR-0061, GAP-047). A developer's machine may not have it running.
- **The host checks start the app synchronously.** The kit's shared functional tests (`tools/AppTests/Functional`) start the sample through `AppHost.Start`, which returns at once, and about 20 places construct a host. Each test class's constructor builds its host.
- **DAT-004:** the app never migrates a server database at startup outside local development; the deployment applies a migration bundle first. The load test (ADR-0062) starts the app in Production, so something has to apply the migrations before it.
- **Moving the engine changed behavior.** SQL Server's default collation ignores case, it compares a `uniqueidentifier` by its last six bytes first (a UUID version 7's random part), and it caps a nonclustered index key at 1,700 bytes. SQLite hid all three; the sample's tests found them on the first CI run on SQL Server.

## Options

### Option 1: One container per test process, a new database per test or host, lazily started; the load test applies a bundle from a pinned image

`sample/tests/SqlServer/SqlServerTestDatabase.cs`, compiled into the integration and functional test projects, starts one SQL Server container the first time a test asks for a database, keeps it for the process, and gives each caller a new database with the migrations applied (`Migrate`). Testcontainers' resource reaper removes the container when the process ends. Without Docker, a local run skips each test with the reason and what to do, and a CI run (`CI=true`) fails it. The image is pinned once, by digest, in `sample/tests/SqlServer/Dockerfile`, which the tests read and Dependabot moves. `performance.reusable.yml`'s load job takes the pin, the migrations project and the connection string's name: it starts SQL Server with a password made and masked for the run, installs `dotnet-ef` at the kit's pinned version, and applies a migration bundle before the app starts.

- **Trade-offs:** About 20 seconds to start SQL Server once per test process, then a database per host in well under a second, so tests stay isolated and can run in parallel. The host's constructor waits for the start synchronously, once, on the thread pool. A database per host is never dropped; they die with the container. The bundle exercises DAT-004's own mechanism. The load job's inputs are SQL Server's only; another engine would add its own.
- **Reversibility:** Easy: the helper is one file, and the load job's inputs default to off.
- **Risk:** Low. A missing Docker in CI fails loudly; a broken image pin fails every database test at once.

### Option 2: A container per test class (an xUnit class fixture)

- **Trade-offs:** Each class gets its own server, but pays the 20-second start, about 15 times per run. The shared host checks construct hosts outside any fixture, so they'd still need Option 1's helper.
- **Reversibility:** Easy.
- **Risk:** Medium: a much slower suite, and Stryker reruns it per mutant.

### Option 3: One database, cleaned between tests (Respawn or a transaction per test)

- **Trade-offs:** No database per host, but tests that share a database can't run in parallel, a cleanup package is one more dependency, and a transaction per test hides what a real commit does (DAT-024).
- **Reversibility:** Moderate.
- **Risk:** Medium: a test that forgets the cleanup leaks rows into the next.

For the load test's database, the other options were a setup script the caller passes to the reusable workflow, which is more general but needs its own Pester-tested script in each app for what is today one engine; and a GitHub Actions service container, which a reusable workflow can't turn on per caller.

## Recommendation

Option 1: the isolation of a database per test at the cost of one container start, with the same image and the same migrations in the tests, the load test and a developer's machine.

## Decision

Proposed (auto mode, ADR-0035); the owner accepts or changes it.

## Consequences

- The sample runs on SQL Server (`Microsoft.EntityFrameworkCore.SqlServer`, with `EnableRetryOnFailure`, DAT-007) and its schema comes from `Migrations/InitialCreate`. `Program.cs` no longer calls `EnsureCreated`, and `StartupTests` proves the app starts with a database nothing answers for.
- The schema answers what SQL Server changed: `OwnerId` and `Url` use a binary collation (SEC-009), pages order by creation time with the key as the tie-breaker (API-004), and the table is clustered on `(OwnerId, CreatedAt)` with a nonclustered key, since the key's random bits would put each insert at a random place and the URL is too long to be a key column. The first three each have a test that failed on SQL Server first; the clustering has a model test. A lookup by URL reads the owner's rows, and nothing stops the same URL being saved twice by two requests at once, as before; a unique index on the owner and a hash of the URL would, and waits for a need.
- `InfrastructureRegistrationTests` fails on a model change no migration covers (`HasPendingModelChanges`), and `MigrationTests` takes the migrations back off, so `Down` runs too. `.editorconfig` marks every `Migrations` folder as generated code, since EF Core writes migrations in its own style; `BuildConfig.Tests.ps1` builds one as `dotnet ef` writes it.
- `Microsoft.EntityFrameworkCore.Design` is in the Api because `dotnet ef` needs it in the startup project. Its assemblies and Roslyn's land in the API's build output too. A design-time startup project of its own would keep them out of the deployable (CRF-002); it waits for the deployment pipeline (GAP-015), which decides what's published.
- New packages: `Microsoft.EntityFrameworkCore.SqlServer`, `Microsoft.EntityFrameworkCore.Design` (the Api, for design time), `Testcontainers.MsSql`, and the `dotnet-ef` tool; Roslyn's workspace packages are pinned beside `Microsoft.CodeAnalysis.CSharp`, and Dependabot moves Roslyn's and EF Core's in groups. `Microsoft.EntityFrameworkCore.Sqlite` and the SQLite busy-timeout interceptor (ADR-0072) are gone.
- Licenses (SEC-005): the kit's policy allows `Microsoft.Data.SqlClient.SNI.runtime` (Microsoft's distributable-code terms); this repo's `.config/package-licenses.json` allows `Microsoft.Identity.Client.NativeInterop`, whose terms allow use but not distribution, so a server app may use it and a shipped client app may not.
- `Initialize-DevMachine.ps1` reports whether Docker is running. Without it, local runs skip the database tests, so the local coverage gate fails until Docker runs; CI is the gate.
- The web UI fixture's container test (GAP-047) still fails, rather than skips, without Docker. Aligning it with this policy is a follow-up.

## Pillars affected

- **Reliability:** tests on the engine production runs found three behaviors SQLite hid; transient failures retry.
- **Security:** an owner id compares exactly, so a user whose id differs only by case can't read another's bookmarks. No password is in the repo: tests use the container's, the load test makes one per run and masks it, and a developer keeps theirs in user secrets.
- **Cost Optimization:** SQL Server's Developer edition in a container is free for development and testing; no cloud resource.
- **Operational Excellence:** the load test applies migrations the way a deployment will (DAT-004); one image pin, moved by Dependabot.
- **Performance Efficiency:** the load test now measures SQL Server; the clustered index serves the page query, and a lookup by URL reads one owner's rows.

## Sources

- owner, 2026-11-25
- ADR-0053, ADR-0054
- https://dotnet.testcontainers.org/modules/mssql/, retrieved 2026-11-25
- https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying, retrieved 2026-11-25
- https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency, retrieved 2026-11-25
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/configuration-options#exclude-generated-code, retrieved 2026-11-25
- https://learn.microsoft.com/sql/connect/ado-net/sql/compare-guid-uniqueidentifier-values, retrieved 2026-11-25
- https://learn.microsoft.com/sql/sql-server/maximum-capacity-specifications-for-sql-server, retrieved 2026-11-25
