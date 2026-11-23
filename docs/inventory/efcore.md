# Microsoft Learn inventory: Entity Framework Core guidance

Batch R5 read this set. The EntityFramework.Docs table of contents lists 180 pages. 28 were candidates. They produced DAT-014, DAT-015 and DAT-017 to DAT-024, and reworded DAT-009 and DAT-010. Pages are under https://learn.microsoft.com/ef/core/, with a few pages from outside the extract that R5 added (see the batch report). Every verdict was checked on 2026-11-17.

The page list for this set, with every page's guidance-wording score, is in `docs/inventory/efcore-pages.tsv`. Re-check with the `discover-guidance` skill.

| Page | Checked | Verdict |
|---|---|---|
| https://learn.microsoft.com/ef/core/change-tracking/change-detection | 2026-11-17 | out of scope: advanced change-tracking features (notification entities, proxies); the one general line ("Snapshot change tracking is recommended for most applications") is a default |
| https://learn.microsoft.com/ef/core/change-tracking/relationship-changes | 2026-11-17 | new rule DAT-020 |
| https://learn.microsoft.com/ef/core/cli/dotnet | 2026-11-17 | covered by DAT-018 (the same platform-specific startup-project sentence; quote taken from the projects page, which was verified live; the cli pages themselves were read in the local clone only) |
| https://learn.microsoft.com/ef/core/cli/powershell | 2026-11-17 | covered by DAT-018 (same) |
| https://learn.microsoft.com/ef/core/learn-more/community-standups | 2026-11-17 | no guidance |
| https://learn.microsoft.com/ef/core/logging-events-diagnostics/interceptors | 2026-11-17 | out of scope: one rarely used API (singleton, thread-safe interceptors) |
| https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying | 2026-11-17 | new rules DAT-014, DAT-017; also split from DAT-004 |
| https://learn.microsoft.com/ef/core/managing-schemas/migrations/projects | 2026-11-17 | new rule DAT-018 |
| https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency | 2026-11-17 | new rule DAT-015 (split from DAT-007) |
| https://learn.microsoft.com/ef/core/miscellaneous/nullable-reference-types | 2026-11-17 | new rule DAT-021 |
| https://learn.microsoft.com/ef/core/miscellaneous/platforms | 2026-11-17 | out of scope: which .NET implementations EF Core supports, .NET Framework era advice |
| https://learn.microsoft.com/ef/core/modeling/constructors | 2026-11-17 | no guidance worth a rule (private setters tip, service injection caution) |
| https://learn.microsoft.com/ef/core/modeling/data-seeding | 2026-11-17 | new rule DAT-019 (the EnsureCreated-with-Migrations sentence is DAT-011's) |
| https://learn.microsoft.com/ef/core/modeling/relationships/conventions | 2026-11-17 | no guidance: descriptive of conventions |
| https://learn.microsoft.com/ef/core/modeling/table-splitting | 2026-11-17 | no guidance: descriptive, advanced mapping |
| https://learn.microsoft.com/ef/core/performance/advanced-performance-topics | 2026-11-17 | new rule DAT-022 (DbContext pooling, compiled models and cache sizing left out as advanced) |
| https://learn.microsoft.com/ef/core/performance/efficient-querying | 2026-11-17 | covered by DAT-009 (12 quotes); index advice and split queries left out as advanced |
| https://learn.microsoft.com/ef/core/performance/performance-diagnosis | 2026-11-17 | new rule DAT-023 |
| https://learn.microsoft.com/ef/core/providers/sqlite/limitations | 2026-11-17 | out of scope: one provider's limits (DateTimeOffset, migrations on SQLite); the kit's database guide covers SQLite |
| https://learn.microsoft.com/ef/core/testing/choosing-a-testing-strategy | 2026-11-17 | covered by DAT-012 (lead's rewrite) |
| https://learn.microsoft.com/ef/core/testing/testing-with-the-database | 2026-11-17 | new rule DAT-024 |
