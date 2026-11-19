---
topic: data
rules:
  - id: DAT-001
    statement: "Every app that stores data picks its database with docs/database-guide.md, answering in order where the data lives, what shape it has, then any preference; the plan names the database, its price label (Free, Free tier or Paid) and why, and a paid option is listed beside the free default, never dropped (ARC-012, the cost rule)."
    why: "The database is the hardest part of an app to change later, and the cheapest one that fits is the one to start with; asking the same questions in the same order makes the choice repeatable and cheap to review (owner, 2026-11-10; GAP-008)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["owner, 2026-11-10", "ADR-0053", "https://learn.microsoft.com/azure/architecture/guide/technology-choices/data-store-decision-tree, retrieved 2026-11-11"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "the plan-checklist skill's Data heading asks for the choice and its price label, and start-work's plan review checks the plan names them"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/Directory.Packages.props"]
  - id: DAT-002
    statement: "An app with a server relational database reaches it through EF Core, and its schema changes only through EF Core code-first migrations kept in the repo, never EnsureCreated (tests apply the migrations too, DAT-005); a test fails when the model has changes no migration covers."
    why: "Migrations are the reviewable, repeatable record of every schema change, so every environment reaches the same schema the same way (owner, 2026-11-10). EF Core's own guidance (DAT-011) leaves EnsureCreated to data that can be dropped and says not to mix it with migrations; the kit goes further and picks EF Core and migrations for every server relational database. A database on the user's device is the app's own choice: .NET MAUI's local database docs use sqlite-net-pcl, not EF Core (MAU rules)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["owner, 2026-11-10", "ADR-0053"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for EnsureCreated and for a HasPendingModelChanges test, until the sample follows (GAP-025)"
    scope: [web-api, blazor]
    paths: ["**/*Infrastructure*/**", "**/Migrations/**", "**/Program.cs"]
  - id: DAT-011
    statement: "EF Core's EnsureCreated and EnsureDeleted (and their Async forms) are useful when the data is transient and can be dropped when the schema changes, for example during prototyping, in tests, or for local caches. EnsureCreated and migrations don't work well together: if you're using migrations, don't use EnsureCreated to initialize the schema, and if you anticipate using migrations in the future, it's best to start with migrations instead of EnsureCreated."
    why: "EF Core's page says that if any tables exist, EnsureCreated won't initialize the schema, so it can't carry existing data through a model change; migrations update the schema incrementally while preserving existing data."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/managing-schemas/migrations/, retrieved 2026-11-17", "https://learn.microsoft.com/ef/core/managing-schemas/ensure-created, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/"
        retrieved: "2026-11-17"
        text: "The migrations feature in EF Core provides a way to incrementally update the database schema to keep it in sync with the application's data model while preserving existing data in the database."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/ensure-created"
        retrieved: "2026-11-17"
        text: "These methods are useful in scenarios when the data is transient and can be dropped when the schema changes."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/ensure-created"
        retrieved: "2026-11-17"
        text: "For example during prototyping, in tests, or for local caches."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/ensure-created"
        retrieved: "2026-11-17"
        text: "EnsureCreatedAsync and Migrations don't work well together. If you're using Migrations, don't use EnsureCreatedAsync to initialize the schema."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/ensure-created"
        retrieved: "2026-11-17"
        text: "If you anticipate using migrations in the future, it's best to just start with Migrations instead of using EnsureCreatedAsync."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/ensure-created"
        retrieved: "2026-11-17"
        text: "If any tables exist (including tables for another DbContext class), the schema won't be initialized."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for EnsureCreated in an app that has migrations; no analyzer reports it"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/Migrations/**", "**/Program.cs", "**/MauiProgram.cs"]
  - id: DAT-003
    statement: "Every migration of a database that more than one version of the app can reach (a server database, not one on the user's device) keeps working with the version still running: a schema change is split into expand (add, in one release), migrate (move data and code over) and contract (drop or rename, in a later release, once no running version uses the old shape); each call in a migration's Up that drops, renames or alters something, changes data or runs raw SQL carries a '// DAT-003: <reason>' comment, directly above it or at the end of the line it starts on, saying why the running version still works."
    why: "During a deployment, and after a rollback, the old version runs against the new schema; a migration that drops or renames what it reads breaks it (GAP-008). The expand, migrate, contract split is Microsoft's (DAT-013); the comment on each risky call and the CI check that demands it are the kit's (ADR-0054)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0054"]
    enforcement:
      - kind: gate
        in: [app]
        how: "ci: Test-SafeMigrations.ps1 in app-checks.reusable.yml fails on each call in a migration's Up to an operation in the script's $UnsafeOperations list (drops, renames, alters, data changes and raw SQL) that has no DAT-003 comment with a reason. Gates aren't per app type (ADR-0084), so the check also runs on a .NET MAUI app's migrations of its device database, which this rule leaves out: such a call needs a DAT-003 comment saying the database is on the device. A fix for device databases is GAP-030; while this rule is proposed, each finding is a warning on the pull request instead of a failure (ADR-0089)"
      - kind: advisory
        in: [app]
        how: "whether the reason is true, and a tightened constraint (a new foreign key, unique or check constraint the running version's writes could break), which code review checks"
    scope: [web-api, blazor]
    paths: ["**/Migrations/**"]
  - id: DAT-004
    statement: "Migrations of a server database are applied by the deployment, with a migration bundle (or an idempotent SQL script, where someone must review the SQL first), before the new version takes traffic; an app never migrates a server database at startup outside local development. A database on the user's device, which no deployment reaches, is migrated by the app at startup with Migrate."
    why: "Migrating at startup races when several instances start at once on versions of EF Core before 9, needs the app to run with rights to change the schema, and hides a failed migration inside a failed start (GAP-008). EF Core's page leaves startup migration open as a tradeoff (DAT-014); the kit shuts it for server databases and requires the deployment to apply migrations before the new version takes traffic (ADR-0054)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0054"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "nothing deploys an app yet (GAP-015), so the production workflow will apply the bundle once it exists; until then code review checks Program.cs for Migrate against a server database outside development"
    scope: core
    paths: ["**/Program.cs", ".github/workflows/**"]
  - id: DAT-005
    statement: "Integration and functional tests of an app with a server database, and its local development, run against the production database engine, in a container (Testcontainers for tests) or its official emulator (the Azure Cosmos DB emulator), with the app's migrations applied; never the EF Core in-memory provider, and never SQLite standing in for another engine."
    why: "A fake behaves differently from the real engine (case sensitivity, translations, transactions, raw SQL), so tests pass and production fails. EF Core recommends testing against the production database system and discourages the in-memory provider (DAT-012); it still allows a SQLite in-memory fake when a repository layer isn't viable, and ASP.NET Core's integration-test page calls SQLite the recommended choice for in-memory testing. The kit rules SQLite out as a stand-in for another engine, because it differs from that engine in the same ways (GAP-008, ADR-0054), and runs local development on the same engine, so what a developer sees is what production does (owner O8, rules audit 2026-11-12: \"Anything that we can run in docker should probably run in docker\")."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0054", "owner, 2026-11-12", "https://learn.microsoft.com/azure/cosmos-db/emulator-linux, retrieved 2026-11-11"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the test projects' database setup and the app's local development setup (a container or the emulator, not SQLite or the in-memory provider), until the sample proves it (GAP-025)"
    scope: [web-api, blazor]
    paths: ["**/*Tests*/**", "**/*AppHost*/**", "**/compose*.yaml", "**/docker-compose*.yml"]
  - id: DAT-012
    statement: "EF Core apps are recommended to have good test coverage running against their actual production database system; where a test double is needed, the repository pattern is recommended over a fake EF Core provider or a mocked DbSet, SQLite in-memory databases are to be considered if a repository isn't viable, and the EF Core in-memory provider is to be avoided for testing. In ASP.NET Core integration tests, the SQLite provider is the recommended choice for in-memory testing."
    why: "A database fake can pass where the production engine fails, for example on case-sensitive comparison, provider-specific functions or raw SQL; EF Core's own testing guidance weighs the options in this order."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/testing/choosing-a-testing-strategy, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/test/integration-tests?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/testing/choosing-a-testing-strategy"
        retrieved: "2026-11-17"
        text: "We recommend that developers have good test coverage of their application running against their actual production database system."
      - source: "https://learn.microsoft.com/ef/core/testing/choosing-a-testing-strategy"
        retrieved: "2026-11-17"
        text: "If you've decided to use a test double, we recommend implementing the repository pattern, which allows you to stub or mock out your data access layer above EF Core, rather than using a fake EF Core provider (Sqlite/in-memory) or by mocking DbSet."
      - source: "https://learn.microsoft.com/ef/core/testing/choosing-a-testing-strategy"
        retrieved: "2026-11-17"
        text: "If the repository pattern isn't a viable option for some reason, consider using SQLite in-memory databases."
      - source: "https://learn.microsoft.com/ef/core/testing/choosing-a-testing-strategy"
        retrieved: "2026-11-17"
        text: "Avoid the in-memory provider for testing purposes - this is discouraged and only supported for legacy applications."
      - source: "https://learn.microsoft.com/aspnet/core/test/integration-tests?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "The EF-Core in-memory database provider can be used for limited and basic testing, however the SQLite provider is the recommended choice for in-memory testing."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the test projects' database setup; no analyzer sees a test's provider choice"
    scope: core
    paths: ["**/*Tests*/**"]
  - id: DAT-006
    statement: "A cloud database starts on its free offer where the guide names one, with the setting that keeps it inside the free amount (Azure SQL Database: the free limit with AutoPause, which stops billing; Azure Cosmos DB: the free tier with a total throughput limit of 1000 RU/s, which caps throughput but not storage past 25 GB), plus a Cost Management budget alert, the only signal for what a setting can't stop; turning a guard off or moving to a paid tier is the owner's call (ARC-012, the cost rule)."
    why: "A free offer that silently starts billing is the most common surprise cost; the guard is a setting chosen when the resource is created, and a budget only alerts, it doesn't stop spending (owner, 2026-11-10; SEC-003)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["owner, 2026-11-10", "ADR-0053", "https://learn.microsoft.com/azure/azure-sql/database/free-offer, retrieved 2026-11-11", "https://learn.microsoft.com/azure/cosmos-db/free-tier, retrieved 2026-11-11", "https://learn.microsoft.com/azure/cosmos-db/limit-total-account-throughput, retrieved 2026-11-11", "https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets, retrieved 2026-11-11"]
    enforcement:
      - kind: advisory
        in: [app]
        how: "the guard is a setting in infrastructure code, which apps don't have yet (GAP-016), so its check waits (GAP-024); creating a cloud resource is the owner's call in any case (SEC-003)"
    scope: [web-api, blazor]
    paths: ["**/*.bicep", "**/infra/**"]
  - id: DAT-007
    statement: "A connection to any cloud or server database, not only Azure SQL Database, retries transient failures with its provider's execution strategy (EnableRetryOnFailure for SQL Server and Azure SQL, or the provider's own), and where a retried commit could insert a row twice, keys are generated by the client."
    why: "A cloud database drops connections and throttles as a matter of course. Microsoft's Azure SQL Database page asks for retry logic, and EF Core's connection resiliency page says how (DAT-015); the owner extended retries to every cloud or server database, and made client-generated keys the rule wherever a retried commit could add a row twice (rules audit, owner 2026-11-12)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-12"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the provider's registration and any explicit transaction; the sample's SQLite provider has no execution strategy, so the check waits for the sample's move to SQL Server (GAP-025)"
    scope: [web-api, blazor]
    paths: ["**/*Infrastructure*/**"]
  - id: DAT-008
    statement: "An entity that two users or requests can change at the same time carries a concurrency token (a rowversion with IsRowVersion, or IsConcurrencyToken on a property the app changes), and a conflict is reported to the caller (a 409 in an HTTP API) or retried with fresh values, never silently overwritten."
    why: "Without a token, the last write wins and an earlier change is lost with no error; with one, EF Core detects the conflict at SaveChanges, and DAT-016 says how the app must handle it. Which entities need a token, and the 409 for an HTTP API, are the kit's (rules audit, owner 2026-11-12)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-12"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every entity that can be updated; the sample's bookmarks are only created, so it has none yet"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Domain*/**"]
  - id: DAT-009
    statement: "In EF Core data access, it's important not to rush into optimization without data showing a problem. It's important to limit the amount of data going back and forth on the wire: we should only load what's needed. A no-tracking query should be used when the entities retrieved don't need to be updated. It's usually worth giving thought to limiting the number of results, and for pagination that moves one page at a time, consider keyset pagination. When you know in advance which related entities you need, it is always better to use eager loading, and it is recommended to avoid lazy loading. Avoid ToList or ToArray before another LINQ operator. It's important to always use asynchronous APIs rather than synchronous ones, and avoid mixing the two in one application. Raw SQL should generally be a last resort."
    why: "EF Core's defaults are correct but not always fast, and the costly mistakes (N+1 queries, tracking what's only read, filtering in memory) don't show in a small test database (rules audit, owner 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/ef/core/performance/efficient-querying, retrieved 2026-11-17", "https://learn.microsoft.com/ef/core/querying/tracking, retrieved 2026-11-17", "https://learn.microsoft.com/ef/core/performance/, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/performance/"
        retrieved: "2026-11-17"
        text: "it's important not to rush into optimization without data showing a problem"
      - source: "https://learn.microsoft.com/ef/core/performance/"
        retrieved: "2026-11-17"
        text: "As with any networking system, it's important to limit the amount of data going back and forth on the wire. This covers making sure that you only send and load data which you're actually going to need, but also avoiding the so-called \"cartesian explosion\" effect when loading related entities."
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "we should only load what's needed"
      - source: "https://learn.microsoft.com/ef/core/querying/tracking"
        retrieved: "2026-11-17"
        text: "If the entities retrieved from the database don't need to be updated, then a no-tracking query should be used."
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "it's usually worth giving thought to limiting the number of results"
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "For pagination that allows moving one page at a time (as opposed to jumping to arbitrary pages), consider using keyset pagination instead."
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "When dealing with related entities, we usually know in advance what we need to load: a typical example would be loading a certain set of Blogs, along with all their Posts. In these scenarios, it is always better to use eager loading, so that EF can fetch all the required data in one roundtrip."
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "Because lazy loading makes it extremely easy to inadvertently trigger the N+1 problem, it is recommended to avoid it."
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "Avoid using ToList or ToArray if you intend to use another LINQ operator on the result - this will needlessly buffer all results into memory."
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "As a general rule, in order for your application to be scalable, it's important to always use asynchronous APIs rather than synchronous one (e.g. SaveChangesAsync rather than SaveChanges)."
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "Avoid mixing synchronous and asynchronous code in the same application - it's very easy to inadvertently trigger subtle thread-pool starvation issues."
      - source: "https://learn.microsoft.com/ef/core/performance/efficient-querying"
        retrieved: "2026-11-17"
        text: "Raw SQL should generally be used as a last resort, after making sure that EF can't generate the SQL you want, and when performance is important enough for the given query to justify it."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks data access with the optimizing-ef-core-queries skill, since no analyzer sees a query's shape; CA1849 already gates a synchronous SaveChanges in async code and CA2016 an unforwarded cancellation token, but a synchronous ToList isn't flagged"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Repository*.cs"]
  - id: DAT-010
    statement: "In EF Core, FromSql and its parameterization should be used wherever possible. Be very careful when using FromSqlRaw, and always make sure values are either from a safe origin or properly sanitized. Don't manually escape untrusted values to construct SQL queries; use parameterized queries instead. For structural parts that can't be parameterized (table names, column names, sort direction), OWASP's preferred pattern is to map user choices to a strict allow-list of fixed, application-owned values."
    why: "SQL built from a caller's text is SQL injection. EF Core's page says FromSql and FromSqlInterpolated always integrate parameter data as a separate SQL parameter, while FromSqlRaw can be vulnerable if improperly used; OWASP's page says concatenating untrusted values into the query before preparing it defeats parameterization's protection. EF Core's analyzer EF1002 flags an interpolated string passed to a Raw method (rules audit, owner 2026-11-12, which asked to verify EF1002)."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/ef/core/querying/sql-queries, retrieved 2026-11-17", "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/querying/sql-queries"
        retrieved: "2026-11-17"
        text: "FromSql and its parameterization should be used wherever possible."
      - source: "https://learn.microsoft.com/ef/core/querying/sql-queries"
        retrieved: "2026-11-17"
        text: "The FromSql and FromSqlInterpolated methods are safe against SQL injection, and always integrate parameter data as a separate SQL parameter. However, the FromSqlRaw method can be vulnerable to SQL injection attacks, if improperly used."
      - source: "https://learn.microsoft.com/ef/core/querying/sql-queries"
        retrieved: "2026-11-17"
        text: "Be very careful when using FromSqlRaw, and always make sure values are either from a safe origin, or are properly sanitized."
      - source: "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html"
        retrieved: "2026-11-17"
        text: "The preferred patterns are:"
      - source: "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html"
        retrieved: "2026-11-17"
        text: "Concatenating untrusted values into the query before preparing it defeats this protection."
      - source: "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html"
        retrieved: "2026-11-17"
        text: "Do not manually escape untrusted values to construct SQL queries. Use parameterized queries instead."
      - source: "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html"
        retrieved: "2026-11-17"
        text: "for structural parts that cannot be parameterized (table names, column names, sort direction), map user choices to a strict allow-list of fixed, application-owned values."
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: EF Core's analyzer EF1002 (an interpolated string passed to a Raw method) is a warning, which STY-004 makes an error; tools/tests/BuildConfig.Tests.ps1 (the RawSqlInterpolation fixture, where EF1002 reports both its SqlQueryRaw and its ExecuteSqlRaw call)"
      - kind: advisory
        in: [kit, app]
        how: "code review checks a Raw call built by concatenation (whether EF1002 also reports one isn't verified) and that a dynamic part comes from a fixed set of query texts"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Repository*.cs"]
  - id: DAT-013
    statement: "Use expand -> migrate -> contract schema changes to keep old and new app versions compatible during a transition."
    why: "During a deployment, and after a rollback, the old version runs against the new schema; the split keeps both versions working (GAP-008). The kit's check of each risky call in a migration is DAT-003."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/azure/aks/zero-downtime-migration, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/aks/zero-downtime-migration"
        retrieved: "2026-11-17"
        text: "Use expand -> migrate -> contract schema changes to keep old and new app versions compatible during transition."
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks that a breaking schema change is split across releases; Test-SafeMigrations.ps1 (DAT-003) reports each drop, rename, alter, data change or raw SQL in a migration's Up that has no DAT-003 reason, as a warning while DAT-003 is proposed and a failure once it's accepted (ADR-0089)"
    scope: [web-api, blazor]
    paths: ["**/Migrations/**"]
  - id: DAT-014
    statement: "For automated deployment of EF Core migrations, use a migration bundle; use a SQL script instead when the SQL must be reviewed, modified, archived, or handed to a DBA before it is applied. Carefully consider before applying migrations at runtime in production; prefer a migration bundle for automation or a SQL script when review and approval are required, and don't make every application replica run migrations from its entrypoint. Use a separate identity for deployment that has permission to change the schema; the identity the application uses at run time should normally have only the permissions it needs to read and write data. Don't store production connection strings in source control or embed them in the bundle."
    why: "A bundle runs without the SDK or the source and a script can be reviewed first, while startup migration needs the application to have elevated access to change the schema. The kit's tighter rule for server databases, that startup migration is never used outside local development, is DAT-004."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying"
        retrieved: "2026-11-17"
        text: "For automated deployment, use a migration bundle. A bundle is a deployment artifact that can be generated in CI and executed later without the .NET SDK, the EF Core tools, or the application's source code. Use a SQL script instead when the SQL must be reviewed, modified, archived, or handed to a DBA before it is applied."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying"
        retrieved: "2026-11-17"
        text: "Carefully consider before using this approach in production. Prefer a migration bundle for automation or a SQL script when review and approval are required."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying"
        retrieved: "2026-11-17"
        text: "The application must have elevated access to modify the database schema. It's generally good practice to limit the application's database permissions in production."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying"
        retrieved: "2026-11-17"
        text: "Don't install the SDK or run dotnet ef in the application image, and don't make every application replica run migrations from its entrypoint."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying"
        retrieved: "2026-11-17"
        text: "Use a separate identity for deployment that has permission to change the schema. The identity used by the application at run time should normally have only the permissions the application needs to read and write data."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying"
        retrieved: "2026-11-17"
        text: "Don't store production connection strings in source control or embed them in the bundle."
    enforcement:
      - kind: advisory
        in: [app]
        how: "nothing deploys an app yet (GAP-015), so the production workflow will apply the bundle once it exists; until then code review checks Program.cs for Migrate against a server database outside development"
    scope: [web-api, blazor]
    paths: ["**/Program.cs", ".github/workflows/**"]
  - id: DAT-015
    statement: "An app that connects to Azure SQL Database should be built to expect transient errors, and implements retry logic for them instead of surfacing them to users as application errors. When code that uses a retrying EF Core execution strategy starts its own transaction, the solution is to invoke the execution strategy manually with a delegate representing everything that needs to be executed. Where an app lets a failed commit simply fail, it needs to avoid store-generated keys so that an exception is thrown instead of a duplicate row being added, and should consider a client-generated GUID or a client-side value generator."
    why: "A cloud database drops connections and throttles as a matter of course. EF Core retries through an execution strategy, and its SQL Server provider includes one tailored to SQL Server and Azure SQL. EF Core's page says that when a connection drops while a transaction is being committed its resulting state is unknown, and that enabling retries makes EF buffer the resultset, which may significantly increase memory requirements for large ones (rules audit, owner 2026-11-12)."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/azure/azure-sql/database/troubleshoot-common-connectivity-issues, retrieved 2026-11-17", "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/azure/azure-sql/database/troubleshoot-common-connectivity-issues"
        retrieved: "2026-11-17"
        text: "Applications that connect to your database should be built to expect these transient errors. To handle them, implement retry logic in their code instead of surfacing them to users as application errors."
      - source: "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency"
        retrieved: "2026-11-17"
        text: "The feature can be used with any database by supplying an \"execution strategy\", which encapsulates the logic necessary to detect failures and retry commands."
      - source: "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency"
        retrieved: "2026-11-17"
        text: "The likelihood of a connection failure during transaction commit is low so it may be acceptable for your application to just fail if this condition actually occurs."
      - source: "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency"
        retrieved: "2026-11-17"
        text: "As an example, the SQL Server provider includes an execution strategy that is specifically tailored to SQL Server (including SQL Azure)."
      - source: "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency"
        retrieved: "2026-11-17"
        text: "The solution is to manually invoke the execution strategy with a delegate representing everything that needs to be executed."
      - source: "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency"
        retrieved: "2026-11-17"
        text: "However, you need to avoid using store-generated keys in order to ensure that an exception is thrown instead of adding a duplicate row. Consider using a client-generated GUID value or a client-side value generator."
      - source: "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency"
        retrieved: "2026-11-17"
        text: "However, if the connection is dropped while the transaction is being committed the resulting state of the transaction is unknown."
      - source: "https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency"
        retrieved: "2026-11-17"
        text: "Enabling retry on failure causes EF to internally buffer the resultset, which may significantly increase memory requirements for queries returning large resultsets."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the provider's registration and any explicit transaction; the sample's SQLite provider has no execution strategy, so the check waits for the sample's move to SQL Server (GAP-025)"
    scope: [web-api, blazor]
    paths: ["**/*Infrastructure*/**"]
  - id: DAT-016
    statement: "To implement optimistic concurrency in EF Core, the application must properly handle the case where a concurrency conflict occurs and SaveChanges throws a DbUpdateConcurrencyException: it must catch and handle the exception appropriately, possibly by retrying the entire operation on the new data."
    why: "EF Core configures a property as a concurrency token and arranges for the update to fail on save if the data has changed since it was queried; without handling that failure, a conflict surfaces as an unhandled exception (rules audit, owner 2026-11-12). Which entities carry a token, and the 409 for an HTTP API, are DAT-008."
    layer: outside
    basis: authority
    status: accepted
    ratified: "owner, 2026-11-12"
    sources: ["https://learn.microsoft.com/ef/core/saving/concurrency, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/saving/concurrency"
        retrieved: "2026-11-17"
        text: "As a result, EF Core's SaveChanges() throws a DbUpdateConcurrencyException, which the application must catch and handle appropriately."
      - source: "https://learn.microsoft.com/ef/core/saving/concurrency"
        retrieved: "2026-11-17"
        text: "Regardless of how your concurrency token is set up, to implement optimistic concurrency, your application must properly handle the case where a concurrency conflict occurs and DbUpdateConcurrencyException is thrown; this is called resolving a concurrency conflict."
      - source: "https://learn.microsoft.com/ef/core/saving/concurrency"
        retrieved: "2026-11-17"
        text: "This concurrency failure is reported to the application, which deals with it accordingly, possibly by retrying the entire operation on the new data."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that each SaveChanges on an entity with a concurrency token handles DbUpdateConcurrencyException; the sample's bookmarks are only created, so it has none yet"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Domain*/**"]
  - id: DAT-017
    statement: "Always inspect the generated EF Core migrations and test them before applying them to a production database, and you should always review a generated migration's code to make sure it corresponds to the desired change. Don't delete a migration that has been applied to a shared, test, or production database; usually keep it in the project and add a new corrective migration. To detect, before deployment, a model that has pending changes compared to the last migration, use dotnet ef migrations has-pending-model-changes in the CI/CD pipeline."
    why: "A migration may drop a column when the intent was to rename it, or may fail for various reasons when applied to a database; a model change that no migration covers is what the CI check finds before deployment."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying, retrieved 2026-11-17", "https://learn.microsoft.com/ef/core/managing-schemas/migrations/managing, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying"
        retrieved: "2026-11-17"
        text: "Whatever your deployment strategy, always inspect the generated migrations and test them before applying to a production database. A migration may drop a column when the intent was to rename it, or may fail for various reasons when applied to a database."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/managing"
        retrieved: "2026-11-17"
        text: "While EF Core generally creates accurate migrations, you should always review the code and make sure it corresponds to the desired change; in some cases, it is even necessary to do so."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/managing"
        retrieved: "2026-11-17"
        text: "Don't delete a migration that has been applied to a shared, test, or production database. Usually, keep the migration in the project and add a new corrective migration."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying"
        retrieved: "2026-11-17"
        text: "Starting with EF Core 9, calling Migrate() or MigrateAsync() will throw an exception when the model has pending changes compared to the last migration (warning event ID RelationalEventId.PendingModelChangesWarning). To detect this condition before deployment, use the dotnet ef migrations has-pending-model-changes command in your CI/CD pipeline."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that a migration was read and its model snapshot kept; no CI step runs has-pending-model-changes yet, and the HasPendingModelChanges test in DAT-002 waits for the sample (GAP-025)"
    scope: core
    paths: ["**/Migrations/**", ".github/workflows/**"]
  - id: DAT-018
    statement: "In a platform-specific app that uses EF Core migrations, such as a .NET MAUI or WinUI app, storing the migrations in a different project from the one containing the DbContext is recommended. Don't use the platform-specific application project as the startup project for EF tools, and prefer an AnyCPU migrations project."
    why: "EF Core's page says mobile, browser, desktop, function and RID-specific projects can require a workload or native host that dotnet ef can't execute. This applies only where an app chooses EF Core: .NET MAUI's local database docs use sqlite-net-pcl, not EF Core."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/managing-schemas/migrations/projects, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/projects"
        retrieved: "2026-11-17"
        text: "You can store migrations in a different project from the one containing your DbContext. This is recommended when the application project is platform-specific, such as WinUI, .NET MAUI, Blazor WebAssembly, or Azure Functions, or when it targets a specific runtime identifier (RID)."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/projects"
        retrieved: "2026-11-17"
        text: "Don't use a platform-specific application project as the startup project for EF tools. Mobile, browser, desktop, function, and RID-specific projects can require a workload or native host that dotnet ef can't execute."
      - source: "https://learn.microsoft.com/ef/core/managing-schemas/migrations/projects"
        retrieved: "2026-11-17"
        text: "Prefer an AnyCPU migrations project."
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks which project the app's EF tools use as startup project; no analyzer sees it"
    scope: [maui]
    paths: ["**/Migrations/**", "**/*.csproj"]
  - id: DAT-019
    statement: "UseSeeding and UseAsyncSeeding are the recommended way of seeding the database with initial data when working with EF Core; always implement UseSeeding even if the app normally uses asynchronous APIs. Custom seeding code, for when those methods aren't a good solution, should not be part of the normal app execution."
    why: "EF Core's tooling and bundles rely on the synchronous delegate; seeding in normal app execution can cause concurrency issues when several instances run, and needs permission to change the schema."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/modeling/data-seeding, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/modeling/data-seeding"
        retrieved: "2026-11-17"
        text: "Using UseSeeding and UseAsyncSeeding is the recommended way of seeding the database with initial data when working with EF Core."
      - source: "https://learn.microsoft.com/ef/core/modeling/data-seeding"
        retrieved: "2026-11-17"
        text: "EF Core tooling and bundles currently rely on the synchronous delegate, so always implement UseSeeding even if your application normally uses asynchronous APIs."
      - source: "https://learn.microsoft.com/ef/core/modeling/data-seeding"
        retrieved: "2026-11-17"
        text: "The seeding code should not be part of the normal app execution as this can cause concurrency issues when multiple instances are running and would also require the app having permission to modify the database schema."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks how an app seeds data and that it doesn't seed in its normal startup; no analyzer sees it"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/Program.cs", "**/MauiProgram.cs"]
  - id: DAT-020
    statement: "Manipulating a relationship in EF Core through its navigations, leaving foreign key values to be updated automatically, is the recommended way. Don't write code to manipulate all navigations and foreign key values each time a relationship changes, and avoid manipulating both navigations and foreign key values."
    why: "Code that touches both is more complicated and must keep foreign keys and navigations consistent in every case."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/change-tracking/relationship-changes, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/change-tracking/relationship-changes"
        retrieved: "2026-11-17"
        text: "In the previous section, relationships were manipulated by navigations leaving foreign key values to be updated automatically. This is the recommended way to manipulate relationships in EF Core."
      - source: "https://learn.microsoft.com/ef/core/change-tracking/relationship-changes"
        retrieved: "2026-11-17"
        text: "Do not write code to manipulate all navigations and FK values each time a relationship changes."
      - source: "https://learn.microsoft.com/ef/core/change-tracking/relationship-changes"
        retrieved: "2026-11-17"
        text: "Avoid manipulating both navigations and FK values."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks code that changes a relationship; no analyzer sees it"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Domain*/**"]
  - id: DAT-021
    statement: "In an EF Core model with nullable reference types, collection navigations should always be non-nullable: an empty collection means that no related entities exist, and the list itself should never be null."
    why: "An empty collection already says that no related entities exist, so a null list adds a second way to say it."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/miscellaneous/nullable-reference-types, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/miscellaneous/nullable-reference-types"
        retrieved: "2026-11-17"
        text: "Collection navigations, which contain references to multiple related entities, should always be non-nullable. An empty collection means that no related entities exist, but the list itself should never be null."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks entity types' collection navigations; no analyzer sees it"
    scope: core
    paths: ["**/*Domain*/**", "**/*Infrastructure*/**"]
  - id: DAT-022
    statement: "It's highly recommended to avoid constant query recompilation in EF Core. Avoid constructing queries with the expression tree API unless you really need to."
    why: "The page says the constant version continuously pollutes the cache and causes other queries to be re-compiled, slowing them down as well."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/performance/advanced-performance-topics, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/performance/advanced-performance-topics"
        retrieved: "2026-11-17"
        text: "Even if the sub-millisecond difference seems small, keep in mind that the constant version continuously pollutes the cache and causes other queries to be re-compiled, slowing them down as well and having a general negative impact on your overall performance. It's highly recommended to avoid constant query recompilation."
      - source: "https://learn.microsoft.com/ef/core/performance/advanced-performance-topics"
        retrieved: "2026-11-17"
        text: "Avoid constructing queries with the expression tree API unless you really need to."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks dynamically built queries with the optimizing-ef-core-queries skill; no analyzer sees it"
    scope: core
    paths: ["**/*Infrastructure*/**", "**/*Repository*.cs"]
  - id: DAT-023
    statement: "With an EF Core performance problem, it's important to carefully diagnose and investigate it before jumping to any conclusions, and to avoid assuming where the root of the issue is. When benchmarking, it's strongly recommended to use the BenchmarkDotNet library, and always make sure to have data in the database that is similar to production data."
    why: "A benchmark on a database that doesn't look like production may not represent actual performance in production."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/performance/performance-diagnosis, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/performance/performance-diagnosis"
        retrieved: "2026-11-17"
        text: "It's important to carefully diagnose and investigate any problems before jumping to any conclusions, and to avoid assuming where the root of the issue is."
      - source: "https://learn.microsoft.com/ef/core/performance/performance-diagnosis"
        retrieved: "2026-11-17"
        text: "When writing benchmarks, it's strongly recommended to use the well-known BenchmarkDotNet library, which handles many pitfalls users encounter when trying to write their own benchmarks"
      - source: "https://learn.microsoft.com/ef/core/performance/performance-diagnosis"
        retrieved: "2026-11-17"
        text: "Always make sure to have data in your database that is similar to production data when benchmarking, otherwise the benchmark results may not represent actual performance in production."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks a performance change for the measurement behind it; TST-009's benchmarks run in CI (ADR-0062), but they don't check the data they run on"
    scope: core
    paths: ["**/*Benchmarks*/**", "**/*Infrastructure*/**"]
  - id: DAT-024
    statement: "Tests that run against a real database keep test isolation and parallelization in mind: a test that modifies data and also explicitly manages transactions must clean up the database to its original state after each test, and parallelization must be disabled for these tests; creating and using many test databases isn't problematic and should be done whenever it's helpful."
    why: "Tests that share one database interfere with each other when they run in parallel or leave committed data behind, and the failures look random."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/ef/core/testing/testing-with-the-database, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/ef/core/testing/testing-with-the-database"
        retrieved: "2026-11-17"
        text: "There is one final category of tests which presents an additional difficulty: tests which modify data and also explicitly manage transactions."
      - source: "https://learn.microsoft.com/ef/core/testing/testing-with-the-database"
        retrieved: "2026-11-17"
        text: "While these tests tend to be more rare, it's necessary to handle them in a special way: you must clean up your database to its original state after each test, and parallelization must be disabled so that these tests don't interfere with each other."
      - source: "https://learn.microsoft.com/ef/core/testing/testing-with-the-database"
        retrieved: "2026-11-17"
        text: "Creating and using many test databases isn't problematic and should be done whenever it's helpful."
      - source: "https://learn.microsoft.com/ef/core/testing/testing-with-the-database"
        retrieved: "2026-11-17"
        text: "Always keep test parallelization and isolation in mind."
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the test projects' database fixtures; no analyzer sees test isolation"
    scope: core
    paths: ["**/*Tests*/**"]
---

# Data

How an app stores its data: which database it picks (DAT-001, `docs/database-guide.md`, ADR-0053), how its schema changes (DAT-002 to DAT-004, ADR-0054, and EF Core's own guidance in DAT-011, DAT-013, DAT-014, DAT-017 and DAT-018), how its tests and local development reach the database (DAT-005, with EF Core's testing guidance in DAT-012 and DAT-024), how a cloud database stays free until the owner decides otherwise (DAT-006), and how the code reaches the data: resilient connections (DAT-007, DAT-015), no lost updates (DAT-008, DAT-016), efficient queries (DAT-009, DAT-022, DAT-023), parameterized SQL (DAT-010), seeding (DAT-019) and the model (DAT-020, DAT-021).

A rule with `basis: authority` states only what its cited page says, at the page's own strength, and stores the sentence that says it. The kit's and the owner's tightenings are `basis: preference` rules beside them: DAT-002 (EF Core and migrations for every server relational database) and DAT-003 (the `// DAT-003:` comment) beside DAT-011 and DAT-013, DAT-004 (never migrate a server database at startup) beside DAT-014, DAT-005 (no fakes) beside DAT-012, DAT-007 (retries for every cloud or server database) beside DAT-015, and DAT-008 (a token on every entity that can change at once) beside DAT-016. EF Core rules apply to an app that uses EF Core. A database on the user's device is reached however the app chooses; .NET MAUI's local database docs use sqlite-net-pcl, so a MAUI app is under them only if it picks EF Core.

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

`Test-SafeMigrations.ps1` runs in the shared app checks (`app-checks.reusable.yml`). An app runs it as `./.kit/tools/Test-SafeMigrations.ps1 -Path .`. It reads each migration's `Up` method and reports each call to an operation that removes or changes what the running version uses, unless that call has a `// DAT-003:` comment with a reason: it warns while DAT-003 is proposed, and fails once it's accepted (ADR-0089). The operations are listed once, in the script's `$UnsafeOperations`: drops, renames and alters, changes to existing data, and raw `Sql`, which could do anything. It can't tell whether the reason is true, or whether a new constraint (a foreign key, unique or check constraint) would reject the running version's writes; code review checks those. It reads the C# as text, so a migration that builds its operations in a helper method isn't checked.

Generate each migration with `dotnet ef migrations add <Name>`, read it before committing, and keep the model snapshot that comes with it. A test that calls `context.Database.HasPendingModelChanges()` fails when someone changes the model and forgets the migration.

## Applying migrations

The deployment applies them, before the new version takes traffic (DAT-004). Build a migration bundle with `dotnet ef migrations bundle`, and run it with the connection string from the deployment's secret store. Use `dotnet ef migrations script --idempotent` instead when someone must read the SQL first. `context.Database.Migrate()` at startup is for local development only. Rolling back a release means deploying the previous version, which still works because of expand and contract; roll the schema forward with a new migration rather than running `Down`.

## Testing against the real engine

Tests that touch the database, and local development, run against the same engine as production (DAT-005), with the app's migrations applied. EF Core's own testing guidance (DAT-012) recommends good test coverage against the production database system, a repository over a fake provider or a mocked `DbSet` when a double is needed, and avoiding the in-memory provider; the kit adds that local development uses the real engine too, and never SQLite standing in for another engine. Tests that commit data keep their isolation in mind (DAT-024). For local development that's a container (Docker Compose, or .NET Aspire's AppHost) or the official emulator:

- **SQL Server or Azure SQL Database:** the `Testcontainers.MsSql` package starts `mcr.microsoft.com/mssql/server` in Docker for the test run. The container's Developer edition is licensed for development and testing only, and needs `ACCEPT_EULA=Y`.
- **PostgreSQL:** `Testcontainers.PostgreSql`, the same way.
- **Azure Cosmos DB:** the Linux emulator image `mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-latest`, which .NET reaches over HTTPS (`--protocol https`).

These need Docker on the developer's machine. GitHub's `ubuntu-latest` runners have it.

## Free-tier guards

The free offers and the setting that keeps each free are in `docs/database-guide.md`. Creating a cloud resource is the owner's call (SEC-003), so an agent writes the setting into the plan, or the infrastructure code once apps have it (GAP-016), and the owner creates the resource.

## Not yet in the sample

The sample app still uses SQLite, with `EnsureCreated` at startup. Moving it to SQL Server with migrations and Testcontainers, to prove DAT-002 and DAT-005 the way the sample proves the other rules, is GAP-025.

## Pending ratification

DAT-001 to DAT-006 were added in auto mode (ADR-0035), so they stay `proposed` until you accept them, as do DAT-011 to DAT-014 and DAT-017 to DAT-024, which re-source those rules and add EF Core's guidance (2026-11-17). DAT-007 to DAT-010, and DAT-015 and DAT-016, which split from DAT-007 and DAT-008, came from the rules audit, which you accepted on 2026-11-12.
