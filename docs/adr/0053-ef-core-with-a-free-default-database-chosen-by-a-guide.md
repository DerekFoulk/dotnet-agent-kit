# ADR-0053: EF Core, with a free default database chosen by a guide

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

The kit said nothing about how an app stores its data: which database, which data access library, or what it costs (scorecard GAP-008). The sample uses SQLite through EF Core, created at startup with `EnsureCreated`, which suits a demo and nothing deployed.

The owner decided on 2026-11-10 that apps use EF Core with code-first migrations by default, that Azure Cosmos DB stays an option, and that a guide recommends the database by asking, in order, where the data lives, what shape it has, then any preference. He also asked that every option carry a price label (Free, Free tier or Paid), with its price, source and the date it was checked, that a paid option is never dropped, and that there is a free default.

Azure has two free offers with no end date: the Azure SQL Database free offer (100,000 vCore seconds, 32 GB of data and 32 GB of backup per database per month, up to 10 databases) and the Azure Cosmos DB free tier (1000 RU/s and 25 GB per account, one account per subscription). Microsoft positions the Azure SQL free offer for development and proof of concept, with no SLA. Its free limit, chosen when the database is created, can auto-pause it instead of billing. The Cosmos DB free tier's total throughput limit caps throughput at the free amount, but storage past 25 GB still bills. Azure Database for PostgreSQL is free for 12 months with an Azure free account, then bills.

## Options

### Option 1: A decision guide with a free default for each data shape

`docs/database-guide.md` asks the owner's three questions. It picks SQLite for data that stays on the device, the Azure SQL Database free offer for relational server data, and the Cosmos DB free tier for document data. Every option is listed with its label, free amount, guard and price. DAT-001 requires the plan to name the choice and its label. DAT-006 requires the guard.

- **Trade-offs:** The choice is repeatable and costs nothing by default, and the owner sees the price of every alternative. Prices go stale, so each carries its date, and the guide says to check again before deciding. The Azure SQL free offer pauses when idle, has no SLA and is meant for development and proof of concept, so an app with users who can't wait, or that needs an SLA, moves to a paid tier, which the guide lists. Cosmos DB storage past 25 GB has no guard but the budget alert.
- **Reversibility:** Easy for a new app. Changing an app's engine later means new migrations and tests, which is why the guide asks first.
- **Risk:** Low.

### Option 2: One database for every app (Azure SQL Database)

- **Trade-offs:** Simplest to support, but wrong for document data and for an app whose data stays on the device. The owner asked for Cosmos DB to stay an option.
- **Reversibility:** Moderate.
- **Risk:** Medium: apps would be bent to fit the database.

### Option 3: No default; the agent researches each time

- **Trade-offs:** No guide to keep current, but every app's choice is made from scratch, prices may be missed, and the owner can't predict the result.
- **Reversibility:** Easy.
- **Risk:** Medium: a paid option could be chosen without anyone noticing.

## Recommendation

Option 1: it's what the owner asked for, and it gives every app a free start with the paid alternatives in view.

## Decision

Proposed (auto mode, ADR-0035), with DAT-001, DAT-002 and DAT-006; the owner accepts or changes it. The choice of EF Core with code-first migrations and of the guide's questions is the owner's (2026-11-10).

## Consequences

- New `docs/standards/data.md` with DAT-001, DAT-002 and DAT-006 (proposed), and `docs/database-guide.md`.
- The plan-checklist skill's Data heading asks for the database choice and its price label.
- The free-tier guard can't be checked until apps have infrastructure as code (GAP-016); that check is GAP-024. Until then it's advisory, and creating the resource is the owner's call (SEC-003).
- The sample still uses SQLite with `EnsureCreated`; moving it to SQL Server with migrations and Testcontainers is GAP-025.
- The guide's prices need a fresh check whenever an app picks its database.

## Pillars affected

- **Cost Optimization:** a free default with a guard against billing past it, and every price in view.
- **Reliability:** the guide names the free offers' trade-offs (pausing, no SLA, a 12-month end).
- **Operational Excellence:** one repeatable way to choose.

## Sources

- owner, 2026-11-10
- https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/data-store-decision-tree, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/cosmos-db/free-tier, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-deploy-on-azure-free-account, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/, retrieved 2026-11-11
- https://prices.azure.com/api/retail/prices, retrieved 2026-11-11
