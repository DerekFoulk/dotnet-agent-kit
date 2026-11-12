# ADR-0053: Safe migrations, checked in CI and tested on the real engine

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

Nothing in the kit said how an app's schema may change (scorecard GAP-008: "no rule for safe database migrations: backward-compatible steps, tested before deploy"). While a release rolls out, and after a rollback, the version that was running keeps running against the new schema. A migration that drops or renames something it reads breaks it.

The Well-Architected Framework asks for backward-compatible changes so a release can roll back. Microsoft's AKS guidance names the pattern: expand, migrate, contract. EF Core's docs recommend migration bundles or SQL scripts for applying migrations in production, and say runtime `Migrate` at startup is a trade-off that suits local development. They also recommend testing against the production database system, with Testcontainers if needed, and discourage the in-memory provider and SQLite as a stand-in.

An EF Core migration is C# that EF scaffolds in a fixed shape: `Up(MigrationBuilder)` then `Down(MigrationBuilder)`, with one `migrationBuilder.<Operation>(...)` call per change.

## Options

### Option 1: Rules for expand and contract, bundles and real-engine tests, plus a text check of each migration's Up

DAT-003 to DAT-005. `Test-SafeMigrations.ps1` reads every C# file with an `Up(MigrationBuilder)` override and fails on a call in `Up` to an operation that removes or changes what the running version uses: `DropTable`, `DropColumn`, `RenameTable`, `RenameColumn`, `AlterColumn`, `DropSchema`, `DropSequence`, `RenameSequence`, `DeleteData`, and `Sql`. A contract step passes once its file has a `// DAT-003: <reason>` comment, which the reviewer reads.

- **Trade-offs:** No package, no build and no database needed, so it runs in every app's checks in seconds, before anything is deployed. It reads text, so a migration that builds its operations in a helper isn't checked, and it can't tell whether a reason is true. Adding a non-nullable column with no default isn't flagged; EF scaffolds a default for a required column on an existing table.
- **Reversibility:** Easy. Drop the step and the script.
- **Risk:** Low. A false alarm costs one comment.

### Option 2: A Roslyn analyzer

- **Trade-offs:** Exact, since it sees the compiled calls, including helpers. But it's a package to build, version and ship to every app, for the same list of operations.
- **Reversibility:** Moderate.
- **Risk:** Medium: more to maintain than the problem needs today (CRF-004).

### Option 3: Rules only, with the reviewer checking each migration

- **Trade-offs:** Least work, but a drop in a long migration is easy to miss, and nothing stops it reaching production.
- **Reversibility:** Easy.
- **Risk:** Medium.

### Option 4: Run each migration against the previous release's tests

Apply the new migrations, then run the previous release's test suite against the result.

- **Trade-offs:** The strongest proof, but it needs the previous build, a database container and a deployment workflow that doesn't exist yet (GAP-015).
- **Reversibility:** Moderate.
- **Risk:** Low, but too early.

## Recommendation

Option 1: it stops the common mistake in every app's CI at no cost, and leaves the stronger proof of Option 4 for when apps deploy.

## Decision

Proposed (auto mode, ADR-0035), with DAT-003 to DAT-005; the owner accepts or changes it.

## Consequences

- DAT-003 to DAT-005 (proposed) in `docs/standards/data.md`, in the scorecard's Reliability and Tests areas. GAP-008 is closed.
- `tools/Test-SafeMigrations.ps1`, with Pester tests. Export-KitApp copies it to every app's `.kit/tools/`, and `app-checks.reusable.yml` runs it on every pull request and push; an app with no migrations passes.
- DAT-004 is advisory until the production workflow (GAP-015) applies a migration bundle before the new version takes traffic.
- DAT-005 is advisory until the sample proves it: its move to SQL Server with migrations and Testcontainers is GAP-023. Then local `dotnet test` needs Docker running, which `Initialize-DevMachine.ps1` should report.
- **Follow-up:** Option 4, once apps deploy.

## Pillars affected

- **Reliability:** a release can roll back, and the old version keeps working during a rollout.
- **Operational Excellence:** schema changes are reviewed in the PR and applied by the deployment.
- **Security:** the running app doesn't need rights to change the schema.

## Sources

- https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/safe-deployments, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/aks/zero-downtime-migration, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/managing, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/ef/core/testing/choosing-a-testing-strategy, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/ef/core/testing/testing-with-the-database, retrieved 2026-11-11
