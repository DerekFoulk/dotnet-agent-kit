# Choosing a database

This guide picks the database for an app (DAT-001, ADR-0052). Answer three questions in order. The first answer that settles it wins. Then put the choice, its label and the reason in the plan.

Every option has a label:

- **Free:** costs nothing, ever.
- **Free tier:** free up to a limit; the guard column says what keeps it from billing past that.
- **Paid:** billed from the first hour.

Prices are pay-as-you-go retail prices in US dollars for the East US region, from the Azure Retail Prices API (`https://prices.azure.com/api/retail/prices`), checked on 2026-11-11. They change; check again before the owner decides. "Not verified" means the price couldn't be confirmed when this was written.

## 1. Where does the data live?

| Answer | Choose |
|---|---|
| Only on the user's device (a MAUI or desktop app's own data) | **SQLite**, through EF Core's SQLite provider. Free. Go no further. |
| On a server the app shares between users | Go to question 2. |

## 2. What shape is the data?

| Answer | Choose |
|---|---|
| Tables that refer to each other, with transactions across them (most business apps) | **Azure SQL Database, on the free offer.** The default. Free tier. |
| Documents or key-value items read by one key, with a schema that changes often, or data spread across regions | **Azure Cosmos DB, on the free tier.** Free tier. |

When unsure, pick relational: the kit's rules for migrations (DAT-002) and its check of each migration (DAT-003) cover it, and most apps have related data.

## 3. Any preference?

If the owner prefers another option that fits the answers above (PostgreSQL, a paid tier for an SLA, a database he already runs), use it, and say in the plan what it costs.

## The options

| Option | Label | What's free | Guard that keeps it free | Price past the free amount | Source |
|---|---|---|---|---|---|
| SQLite | Free | Everything: it's a file in the app | None needed | None | [EF Core SQLite provider](https://learn.microsoft.com/en-us/ef/core/providers/sqlite/), checked 2026-11-11 |
| SQL Server in Docker (local development and tests only) | Free | Developer edition, licensed for development and testing only | Never run it in production | None | `mcr.microsoft.com/mssql/server` image, checked 2026-11-11 |
| **Azure SQL Database, free offer** (default for relational data) | Free tier | Each month, per database: 100,000 vCore seconds, 32 GB of data and 32 GB of backup; up to 10 databases per subscription, for the subscription's life | Create it with the free limit on and "auto-pause until next month" (`useFreeLimit: true`, `freeLimitExhaustionBehavior: AutoPause`). The other choice, "continue using database for additional charges" (`BillOverUsage`), can't be switched back. Add an alert on the free "Free amount remaining" metric | General Purpose serverless, Gen5: $0.521758 per vCore-hour, plus $0.115 per GB-month of storage | [Free offer](https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer), checked 2026-11-11; Retail Prices API, 2026-11-11 |
| Azure SQL Database, Basic (DTU) | Paid | Nothing | A budget alert | $0.161 per day | [Pricing page](https://azure.microsoft.com/en-us/pricing/details/azure-sql-database/single/), 2026-11-11 |
| Azure Database for PostgreSQL, flexible server | Free tier, for 12 months | With an Azure free account, for its first 12 months: 750 hours of Burstable B1MS, 32 GB of storage and 32 GB of backup each month | None that stops billing: a budget alert, and a reminder before month 12 | B1MS compute: $0.017 per hour; storage: $0.115 per GB-month | [Free account deployment](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-deploy-on-azure-free-account), checked 2026-11-11; Retail Prices API, 2026-11-11 |
| **Azure Cosmos DB, free tier** (default for document data) | Free tier | 1000 RU/s of provisioned throughput and 25 GB of storage, for the account's life; one free-tier account per subscription; chosen when the account is created; not for serverless accounts | Cap the account's total throughput at 1000 RU/s (`properties.capacity.totalThroughputLimit: 1000`), so no container can be given more than the free amount. Nothing caps storage: past 25 GB it bills, and the budget alert is the only signal | Provisioned throughput: $0.008 per 100 RU/s per hour; storage: $0.25 per GB-month | [Free tier](https://learn.microsoft.com/en-us/azure/cosmos-db/free-tier) and [total throughput limit](https://learn.microsoft.com/en-us/azure/cosmos-db/limit-total-account-throughput), checked 2026-11-11; Retail Prices API, 2026-11-11 |
| Azure Cosmos DB, serverless | Paid | Nothing | A budget alert | $0.25 per million request units, plus storage | Retail Prices API, 2026-11-11 |

## What the free offers trade away

- **Azure SQL Database free offer:** it pauses after about 15 minutes with no connections, so the first request after a pause waits while it resumes. Turn on EF Core's retry for transient errors (`EnableRetryOnFailure`). It has no SLA, and Microsoft positions it for development and proof of concept: an app whose users can't wait or need an SLA moves to a paid tier, which is the owner's call. Once the month's vCore seconds run out, it stays paused until the next month.
- **Cosmos DB free tier:** 1000 RU/s is shared by every container in the account, only one account per subscription can have it, and storage past 25 GB bills at the regular price.
- **PostgreSQL free account:** it ends after 12 months, and then bills at the paid price without asking.

## Every cloud database, whichever it is

- **A budget alert:** a Cost Management budget on the resource group, set to alert the owner. A budget only alerts; it doesn't stop spending ([budgets tutorial](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets), checked 2026-11-11).
- **The owner creates it:** creating a cloud resource, and anything that could cost money, is the owner's call (SEC-003). The agent writes the guard settings into the plan, or into the infrastructure code once apps have it (GAP-016).
- **Tests run on the same engine:** in a container or the emulator, never against the cloud database (DAT-005).

## Sources

- https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/data-store-decision-tree, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/cosmos-db/free-tier, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/cosmos-db/limit-total-account-throughput, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-deploy-on-azure-free-account, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets, retrieved 2026-11-11
- https://prices.azure.com/api/retail/prices, retrieved 2026-11-11
