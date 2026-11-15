---
topic: data
rules:
  - id: DAT-001
    statement: "Every app that stores data picks its database with docs/database-guide.md, answering in order where the data lives, what shape it has, then any preference; the plan names the database, its price label (Free, Free tier or Paid) and why, and a paid option is listed beside the free default, never dropped (ARC-012, the cost rule)."
    why: "The database is the hardest part of an app to change later, and the cheapest one that fits is the one to start with; asking the same questions in the same order makes the choice repeatable and cheap to review (owner, 2026-11-10; GAP-008)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["owner, 2026-11-10", "ADR-0053", "https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/data-store-decision-tree, retrieved 2026-11-11"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "the plan-checklist skill's Data heading asks for the choice and its price label, and start-work's plan review checks the plan names them"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/Directory.Packages.props"]
  - id: DAT-002
    statement: "A relational database is reached through EF Core, and its schema changes only through EF Core code-first migrations kept in the repo; EnsureCreated isn't used, since it can't change a schema that already exists and tests apply the migrations instead (DAT-005), and a test fails when the model has changes no migration covers."
    why: "Migrations are the reviewable, repeatable record of every schema change, so every environment reaches the same schema the same way; EnsureCreated can't change a schema once it exists, so an app that uses it can't evolve its data safely (owner, 2026-11-10)."
    layer: owner
    basis: authority
    status: proposed
    sources: ["owner, 2026-11-10", "ADR-0053", "https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/ef/core/managing-schemas/ensure-created, retrieved 2026-11-11"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for EnsureCreated and for a HasPendingModelChanges test, until the sample follows (GAP-025)"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/Migrations/**", "**/Program.cs"]
  - id: DAT-003
    statement: "Every migration of a database that more than one version of the app can reach (a server database, not one on the user's device) keeps working with the version still running: a schema change is split into expand (add, in one release), migrate (move data and code over) and contract (drop or rename, in a later release, once no running version uses the old shape); each call in a migration's Up that drops, renames or alters something, changes data or runs raw SQL carries a '// DAT-003: <reason>' comment, directly above it or at the end of the line it starts on, saying why the running version still works."
    why: "During a deployment, and after a rollback, the old version runs against the new schema; a migration that drops or renames what it reads breaks it, and the Well-Architected Framework asks for backward-compatible changes so a release can roll back (GAP-008)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["ADR-0054", "https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/safe-deployments, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/aks/zero-downtime-migration, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/managing, retrieved 2026-11-11"]
    enforcement:
      - kind: gate
        in: [app]
        how: "ci: Test-SafeMigrations.ps1 in app-checks.reusable.yml fails on each call in a migration's Up to an operation in the script's $UnsafeOperations list (drops, renames, alters, data changes and raw SQL) that has no DAT-003 comment with a reason"
      - kind: advisory
        in: [app]
        how: "whether the reason is true, and a tightened constraint (a new foreign key, unique or check constraint the running version's writes could break), which code review checks"
    scope: core
    paths: ["**/Migrations/**"]
  - id: DAT-004
    statement: "Migrations are applied by the deployment, with a migration bundle (or an idempotent SQL script, where someone must review the SQL first), before the new version takes traffic; an app never migrates a server database at startup outside local development. A database on the user's device, which no deployment reaches, is migrated by the app at startup with Migrate."
    why: "Migrating at startup races when several instances start at once, needs the app to run with rights to change the schema, and hides a failed migration inside a failed start; Microsoft recommends bundles or scripts for production (GAP-008)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["ADR-0054", "https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying, retrieved 2026-11-11"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "nothing deploys an app yet (GAP-015), so the production workflow will apply the bundle once it exists; until then code review checks Program.cs for Migrate against a server database outside development"
    scope: core
    paths: ["**/Program.cs", ".github/workflows/**"]
  - id: DAT-005
    statement: "Integration and functional tests, and local development, run against the production database engine, in a container (Testcontainers for tests) or its official emulator (the Azure Cosmos DB emulator), with the app's migrations applied; never the EF Core in-memory provider, and never SQLite standing in for another engine."
    why: "A fake behaves differently from the real engine (case sensitivity, translations, transactions, raw SQL), so tests pass and production fails; Microsoft recommends testing against the production database system and discourages the in-memory provider. Microsoft allows SQLite as a fake when a repository layer isn't an option; the kit rules it out as well, because it differs from the engine it replaces in the same ways (GAP-008). Local development runs the same engine, so what a developer sees is what production does (owner O8, rules audit 2026-11-12: \"Anything that we can run in docker should probably run in docker\")."
    layer: outside
    basis: authority
    status: proposed
    sources: ["ADR-0054", "owner, 2026-11-12", "https://learn.microsoft.com/en-us/ef/core/testing/choosing-a-testing-strategy, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/ef/core/testing/testing-with-the-database, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/cosmos-db/emulator-linux, retrieved 2026-11-11"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the test projects' database setup and the app's local development setup (a container or the emulator, not SQLite or the in-memory provider), until the sample proves it (GAP-025)"
    scope: core
    paths: ["**/*Tests*/**", "**/*AppHost*/**", "**/compose*.yaml", "**/docker-compose*.yml"]
  - id: DAT-006
    statement: "A cloud database starts on its free offer where the guide names one, with the setting that keeps it inside the free amount (Azure SQL Database: the free limit with AutoPause, which stops billing; Azure Cosmos DB: the free tier with a total throughput limit of 1000 RU/s, which caps throughput but not storage past 25 GB), plus a Cost Management budget alert, the only signal for what a setting can't stop; turning a guard off or moving to a paid tier is the owner's call (ARC-012, the cost rule)."
    why: "A free offer that silently starts billing is the most common surprise cost; the guard is a setting chosen when the resource is created, and a budget only alerts, it doesn't stop spending (owner, 2026-11-10; SEC-003)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["owner, 2026-11-10", "ADR-0053", "https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/cosmos-db/free-tier, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/cosmos-db/limit-total-account-throughput, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets, retrieved 2026-11-11"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "the guard is a setting in infrastructure code, which apps don't have yet (GAP-016), so its check waits (GAP-024); creating a cloud resource is the owner's call in any case (SEC-003)"
    scope: core
    paths: ["**/*.bicep", "**/infra/**"]
  - id: DAT-007
    statement: "A connection to a cloud or server database retries transient failures with its provider's execution strategy (EnableRetryOnFailure for SQL Server and Azure SQL, or the provider's own), and work that a retry could repeat runs inside the strategy as one unit."
    why: "A cloud database drops connections and throttles as a matter of course; EF Core's execution strategies retry what's transient, and Microsoft's connection resiliency guidance says a user-started transaction must run through the strategy, or a retry repeats only part of it. The same page warns that a retried commit can insert a row twice where keys are store-generated, and that retries make EF Core buffer results, which costs memory (rules audit, owner 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency, retrieved 2026-11-15"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the provider's registration and any explicit transaction; the sample's SQLite provider has no execution strategy, so the check waits for the sample's move to SQL Server (GAP-025)"
    scope: core
    paths: ["**/*Infrastructure*/**"]
  - id: DAT-008
    statement: "An entity that two users or requests can change at the same time carries a concurrency token (a rowversion with IsRowVersion, or IsConcurrencyToken on a property the app changes), and a conflict is reported to the caller (a 409 in an HTTP API) or retried with fresh values, never silently overwritten."
    why: "Without a token, the last write wins and an earlier change is lost with no error; EF Core's optimistic concurrency detects the conflict at SaveChanges (rules audit, owner 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/ef/core/saving/concurrency, retrieved 2026-11-15"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every entity that can be updated; the sample's bookmarks are only created, so it has none yet"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Domain*/**"]
  - id: DAT-009
    statement: "Data access follows Microsoft's EF Core efficient-querying guidance unless a measurement shows otherwise: queries project only what they need, read-only queries don't track, collections are paged in the database, related data loads without N+1 round trips and without lazy loading, and nothing is materialized before it's filtered."
    why: "EF Core's defaults are correct but not always fast, and the costly mistakes (N+1 queries, tracking what's only read, filtering in memory) don't show in a small test database (rules audit, owner 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/ef/core/performance/efficient-querying, retrieved 2026-11-15", "https://learn.microsoft.com/ef/core/querying/tracking, retrieved 2026-11-15", "https://learn.microsoft.com/ef/core/performance/, retrieved 2026-11-15"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks data access with the optimizing-ef-core-queries skill, since no analyzer sees a query's shape; CA1849 already gates a synchronous SaveChanges in async code and CA2016 an unforwarded cancellation token, but a synchronous ToList isn't flagged"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Repository*.cs"]
  - id: DAT-010
    statement: "Raw SQL is parameterized: FromSql and ExecuteSql with an interpolated string, which EF Core turns into parameters, or FromSqlRaw and ExecuteSqlRaw with explicit parameters; never a string built by concatenation or interpolation into a Raw method."
    why: "SQL built from a caller's text is SQL injection, OWASP's oldest top risk; EF Core's interpolated-string methods parameterize every value, and its own analyzer EF1002 flags the unsafe form (rules audit, owner 2026-11-12, where EF1002 was to be verified)."
    layer: outside
    basis: authority
    status: accepted
    sources: ["owner, 2026-11-12", "https://learn.microsoft.com/ef/core/querying/sql-queries, retrieved 2026-11-15", "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html, retrieved 2026-11-15"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: EF Core's analyzer EF1002 (an interpolated string into FromSqlRaw or ExecuteSqlRaw) is a warning, which STY-004 makes an error; a probe in the sample's Infrastructure failed the build with error EF1002 (2026-11-15)"
      - kind: advisory
        in: [kit, app]
        how: "code review checks a Raw call built by concatenation, which EF1002 doesn't see"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Repository*.cs"]
---

# Data

How an app stores its data: which database it picks (DAT-001, `docs/database-guide.md`, ADR-0053), how its schema changes (DAT-002 to DAT-004, ADR-0054), how its tests and local development reach the database (DAT-005), how a cloud database stays free until the owner decides otherwise (DAT-006), and how the code reaches the data: resilient connections (DAT-007), no lost updates (DAT-008), efficient queries (DAT-009) and parameterized SQL (DAT-010).

## Changing the schema safely

This applies to a server database, which the old and new versions of the app reach at the same time. A database on the user's device is only ever opened by the one version installed there, so its app migrates it at startup with `Migrate`, and a drop needs only a `// DAT-003:` comment saying so.

While a release rolls out, and again after a rollback, the version that was running keeps running against the new schema. So every migration must leave that version working. Split a breaking change across releases:

1. **Expand:** add the new table or column, nullable or with a default. Both versions work.
2. **Migrate:** ship code that writes both shapes and reads the new one, then copy the old data across.
3. **Contract:** once no running version reads the old shape, drop or rename it, in a later release. Put a comment directly above that call, or at the end of the line it starts on, that says why it's safe:

   ```csharp
   // DAT-003: release 1.4 stopped reading Notes, and every instance runs 1.4 or later.
   migrationBuilder.DropColumn(name: "Notes", table: "Orders");
   ```

`Test-SafeMigrations.ps1` runs in the shared app checks (`app-checks.reusable.yml`). An app runs it as `./.kit/tools/Test-SafeMigrations.ps1 -Path .`. It reads each migration's `Up` method and fails on each call to an operation that removes or changes what the running version uses, unless that call has a `// DAT-003:` comment with a reason. The operations are listed once, in the script's `$UnsafeOperations`: drops, renames and alters, changes to existing data, and raw `Sql`, which could do anything. It can't tell whether the reason is true, or whether a new constraint (a foreign key, unique or check constraint) would reject the running version's writes; code review checks those. It reads the C# as text, so a migration that builds its operations in a helper method isn't checked.

Generate each migration with `dotnet ef migrations add <Name>`, read it before committing, and keep the model snapshot that comes with it. A test that calls `context.Database.HasPendingModelChanges()` fails when someone changes the model and forgets the migration.

## Applying migrations

The deployment applies them, before the new version takes traffic (DAT-004). Build a migration bundle with `dotnet ef migrations bundle`, and run it with the connection string from the deployment's secret store. Use `dotnet ef migrations script --idempotent` instead when someone must read the SQL first. `context.Database.Migrate()` at startup is for local development only. Rolling back a release means deploying the previous version, which still works because of expand and contract; roll the schema forward with a new migration rather than running `Down`.

## Testing against the real engine

Tests that touch the database, and local development, run against the same engine as production (DAT-005), with the app's migrations applied. For local development that's a container (Docker Compose, or .NET Aspire's AppHost) or the official emulator:

- **SQL Server or Azure SQL Database:** the `Testcontainers.MsSql` package starts `mcr.microsoft.com/mssql/server` in Docker for the test run. The container's Developer edition is licensed for development and testing only, and needs `ACCEPT_EULA=Y`.
- **PostgreSQL:** `Testcontainers.PostgreSql`, the same way.
- **Azure Cosmos DB:** the Linux emulator image `mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-latest`, which .NET reaches over HTTPS (`--protocol https`).

These need Docker on the developer's machine. GitHub's `ubuntu-latest` runners have it.

## Free-tier guards

The free offers and the setting that keeps each free are in `docs/database-guide.md`. Creating a cloud resource is the owner's call (SEC-003), so an agent writes the setting into the plan, or the infrastructure code once apps have it (GAP-016), and the owner creates the resource.

## Not yet in the sample

The sample app still uses SQLite, with `EnsureCreated` at startup. Moving it to SQL Server with migrations and Testcontainers, to prove DAT-002 and DAT-005 the way the sample proves the other rules, is GAP-025.

## Pending ratification

DAT-001 to DAT-006 were added in auto mode (ADR-0035), so they stay `proposed` until you accept them. DAT-007 to DAT-010 came from the rules audit, which you accepted on 2026-11-12.
