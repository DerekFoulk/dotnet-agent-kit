# ADR-0069: SQLite waits for its own write lock in the sample

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The sample's Locust load test (ADR-0062) failed 3 of 25 runs on 2026-11-13 and 14, on branches that don't touch the sample: `POST /bookmarks` had a p95 of 110, 150 and 190 ms against its 100 ms budget, while its median stayed at 3 ms and no request failed. The runs' artifacts hold Locust's stats and the app's log, where EF Core logs how long each SQL command took.

- **The time is in SQLite's INSERT.** In the three red runs, 24 to 73 of about 290 INSERTs took 20 ms or more, up to 423 ms. In green runs, 0 or 1 did, and in the steadiest one no INSERT took more than 2 ms.
- **Many of the slow ones took exactly 151 ms.** 16 of them in the worst run, and others near 300 ms. Microsoft.Data.Sqlite answers a locked database (`SQLITE_BUSY`) by sleeping a fixed 150 ms on the request's thread, then trying again until the command timeout (`SqliteDataReader.NextResult`). It never sets SQLite's own busy timeout, so SQLite reports the lock at once.
- **The rest were the commits that held the lock.** They took 10 to 140 ms in the red runs, against 2 ms or less in green ones. They're spread through the whole run, in bursts, not at the start, so the app's warm-up doesn't explain them. SQLite takes one write at a time, and the SQLite the sample loads (3.53.3, from SQLitePCLRaw's e_sqlite3) is built with `DEFAULT_WAL_SYNCHRONOUS=2`, `FULL`: each commit syncs its log file to disk. The likeliest cause is that runner's disk, shared with other jobs, but the sync time isn't measured on its own.

So on a runner whose disk is slow, commits hold the write lock longer, and two of the ten users' writes overlap more often. Each overlap costs the waiting write at least 150 ms, however soon the lock is free. When more than 5% of the writes overlap, the p95 is 150 ms. Warm-up, too few samples (about 290 POSTs, so the p95 rests on about 15) and the budget aren't the cause: in the worst run, only 6 of the 298 INSERTs took over 100 ms without a 150 ms sleep in them.

A real user of an app on SQLite would see the same pause whenever two writes meet.

## Options

### Option 1: SQLite's own busy timeout on every connection

An EF Core connection interceptor calls `sqlite3_busy_timeout` on each connection EF Core opens, through the `SqliteConnection.Handle` that Microsoft.Data.Sqlite exposes for native calls. SQLite's busy handler then waits for the lock itself, in short sleeps (1, 2, 5, 10, 15, 20, 25 ms and on), and goes on soon after the lock is free. The timeout is as long as a command may run: EF Core's command timeout when one is set, else the connection's `Default Timeout` (30 seconds unless the connection string says otherwise). A timeout of 0, Microsoft.Data.Sqlite's "no limit", becomes SQLite's longest wait (`int.MaxValue` milliseconds), since 0 would turn SQLite's handler off.

- **Trade-offs:** Covers every connection and every statement, writes from other processes too, with no change to the code that writes. A waiting write still blocks its thread while SQLite sleeps, as every Microsoft.Data.Sqlite call does (its async methods run synchronously). It's one small class, with no SQL text built.
- **Reversibility:** Easy: remove the interceptor.
- **Risk:** Low. SQLite sleeps in fractions of a second only where it can: in SQLite 3.41 a Unix build needed `HAVE_USLEEP`, or it slept in whole seconds, and by 3.49 it does unless built with `HAVE_NANOSLEEP=0`. SQLitePCLRaw's Linux build sets neither, and the sample loads 3.53.3; the load test's app log shows each INSERT's time, so a whole-second sleep would show at once. It doesn't help a read-then-write transaction that SQLite refuses at once to avoid a deadlock (`SQLITE_BUSY_SNAPSHOT`); the sample has none.

### Option 2: Queue the app's writes behind an async lock

A `SemaphoreSlim` shared by every `DbContext` (a singleton) is taken around `SaveChanges`, so only one write runs at a time and the others wait without blocking a thread.

- **Trade-offs:** Exact waits and no blocked threads. It covers only writes through `SaveChanges` in this process: `ExecuteUpdate`, `ExecuteDelete`, raw SQL, a second process or a tool on the same file would still meet Microsoft.Data.Sqlite's 150 ms sleep. Every new way of writing must remember the lock.
- **Reversibility:** Easy.
- **Risk:** Medium: a write path that skips the lock brings the pause back silently.

### Option 3: `synchronous=NORMAL`

SQLite syncs its log only at checkpoints, so commits are fast and overlap less.

- **Trade-offs:** SQLite says WAL mode with `NORMAL` can't corrupt the database, but a committed transaction "might roll back following a power loss or system crash": a bookmark the API answered `201 Created` for could vanish. An overlap would still cost 150 ms; it would just happen less often.
- **Reversibility:** Easy.
- **Risk:** Medium: it trades durability for speed, which is a product decision, and hides the 150 ms pause instead of removing it.

### Option 4: Change the measurement

Raise the budget, leave a warm-up out of the stats, or run longer for more samples.

- **Trade-offs:** No code change. The evidence rules out warm-up and sample size, and a higher budget would accept a pause that a user would feel.
- **Reversibility:** Easy.
- **Risk:** High: it works around the defect (CRF-001).

## Recommendation

Option 1: it removes the 150 ms pause for every connection and every kind of write, with the mechanism SQLite provides for exactly this.

## Decision

Option 1, decided in auto mode (ADR-0035) on 2026-11-15, while answering the red load-test runs on PR 70's branch.

## Consequences

- `sample/src/Bookmarks.Infrastructure/SqliteBusyTimeoutInterceptor.cs`, registered in `AddBookmarksInfrastructure`, and `SqliteBusyTimeoutTests` in the integration tests, which read `PRAGMA busy_timeout` on connections opened through the app's own registration.
- Measured on Windows with a write lock held for 20 ms by another connection, 20 saves each: 154 to 160 ms before, about 46 ms after (Windows sleeps in steps of about 15 ms; Linux sleeps closer to SQLite's steps).
- The load test and its budget are unchanged (ADR-0062): it still measures the API and its SQLite file on a shared runner. A slow-disk run still shows its slow commits; it no longer adds 150 ms to every write that waits for one.
- An app that uses SQLite through EF Core needs the same interceptor. Its database guide (`docs/database-guide.md`) picks SQLite only for a device's own data, where writes rarely meet, so the kit doesn't add a rule for it yet.

## Pillars affected

- **Performance Efficiency:** a write that meets another waits about as long as the lock is held, not 150 ms or more.
- **Reliability:** the load test's POST p95 no longer flips red on a runner with a slow disk; writes still fail after the command timeout, as before.
- **Operational Excellence:** the evidence came from the run artifacts ADR-0062 keeps: Locust's stats and the app's log.

## Sources

- https://learn.microsoft.com/dotnet/standard/data/sqlite/database-errors, retrieved 2026-11-15
- https://learn.microsoft.com/dotnet/standard/data/sqlite/interop, retrieved 2026-11-15
- https://learn.microsoft.com/dotnet/standard/data/sqlite/connection-strings, retrieved 2026-11-15
- https://raw.githubusercontent.com/dotnet/efcore/release/10.0/src/Microsoft.Data.Sqlite.Core/SqliteDataReader.cs, retrieved 2026-11-15
- https://www.sqlite.org/c3ref/busy_timeout.html, retrieved 2026-11-15
- https://www.sqlite.org/pragma.html#pragma_synchronous, retrieved 2026-11-15
- https://raw.githubusercontent.com/sqlite/sqlite/version-3.49.1/src/main.c and https://raw.githubusercontent.com/sqlite/sqlite/version-3.41.0/src/main.c (`sqliteDefaultBusyCallback`), retrieved 2026-11-15
- https://github.com/ericsink/cb/blob/master/bld/cb.cs (e_sqlite3's compile options), retrieved 2026-11-15
- GitHub Actions runs 43504641754, 43503299942, 43541215632 and 43561350708 (red), 43675018136 and 43687112597 (green), their `load-test-results` artifacts, retrieved 2026-11-15
