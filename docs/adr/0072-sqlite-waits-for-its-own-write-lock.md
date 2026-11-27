# ADR-0072: SQLite waits for its own write lock in the sample

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The sample's Locust load test (ADR-0062) failed 4 of its 55 runs on 2026-11-13 and 14, all on branches that don't touch the sample. In each, `POST /bookmarks` had a p95 over its 100 ms budget: 110, 140, 150 and 190 ms. Its median stayed at 3 ms, and no request failed. Each run's artifact holds Locust's stats and the app's log, where EF Core logs how long each SQL command took. Ten runs' logs were read: the four red ones and six green ones.

- **The time is in SQLite's INSERT.**
  - Red runs: 24 to 73 of their 262 to 298 INSERTs took 20 ms or more, up to 423 ms.
  - Green runs: 0 to 7 did, and in the steadiest one no INSERT took more than 2 ms.
- **Many of the slow ones took exactly 151 ms.** The worst run had 16, and 6 more between 290 and 314 ms, about two of them. Green runs had 0 to 3 near 151 ms.
  - Microsoft.Data.Sqlite answers a locked database (`SQLITE_BUSY`) by sleeping a fixed 150 ms on the request's thread, then trying again until the command timeout (`SqliteDataReader.NextResult`).
  - It never sets SQLite's own busy timeout, so SQLite reports the lock at once.
  - So the pause comes on every runner, whenever two of the ten users' writes meet. On green runners 0 to 1.4% of the INSERTs took 150 ms or more; on the red ones, 2.4 to 12.8%. In the two red runs whose p95 was 110 and 140 ms, the p95 fell on slow commits under 150 ms, because the sleeps filled only some of the 14 or so places above it.
- **The red runners were slow at everything.**
  - The other slow INSERTs took 10 to 150 ms, against 2 ms or less on the steadiest green runner.
  - SELECTs slowed too: 2 to 6 per red run took 100 to 248 ms, though a read in WAL mode doesn't wait for the write lock. No green run had one.
  - The slow ones come in bursts through the whole run, not only at the start, so the app's warm-up doesn't explain them.
  - A slow commit holds SQLite's one write lock longer, so writes meet more often, and each one that meets it pays the 150 ms sleep on top. The sample's SQLite (3.53.3, read with `sqlite_version()`) uses SQLite's default `DEFAULT_WAL_SYNCHRONOUS=2`, `FULL` (read with `pragma_compile_options`), so each commit syncs its log to disk. Why the runner was slow isn't measured: a shared runner's disk or CPU are both likely.

Without the sleeps, the worst run would likely have been within budget, though that can't be proven from the logs: 7 of its 298 INSERTs took 100 to 150 ms. Every one that took longer than that is consistent with one or two 150 ms sleeps on top of a shorter wait. Too few samples isn't the cause either: about 290 POSTs a run puts about 15 above the p95.

A real user of an app on SQLite would see the same pause whenever two writes meet.

## Options

### Option 1: A short busy timeout on every connection

An EF Core connection interceptor calls `sqlite3_busy_timeout` with 1 second on each connection EF Core opens. It goes through the `SqliteConnection.Handle` that Microsoft.Data.Sqlite exposes for native calls. SQLite's busy handler then waits for the lock itself, polling in sleeps of 1, 2, 5, 10, 15, 20 and 25 ms that grow to 50 and then 100 ms, and goes on about as soon as the lock is free. A lock held longer than a second falls back to Microsoft.Data.Sqlite's own retries, which still end at the command timeout.

- **Trade-offs:** It covers every connection and every statement, including writes from another process, with no change to the code that writes.
  - The busy timeout is per connection and per statement, while Microsoft.Data.Sqlite's command timeout covers a whole command, which can hold several statements (dotnet/efcore#28135). A second is short, so each statement can run past the command's timeout by about a second more than the library already allowed: it checks the timeout only after a step returns busy, and then sleeps 150 ms and steps again. A command timeout is whole seconds, so a second is its smallest step.
  - A waiting write still blocks its thread while SQLite sleeps. Every Microsoft.Data.Sqlite call does that, since its async methods run synchronously.
  - It's one small class, with no SQL text built.
- **Reversibility:** Easy: remove the interceptor.
- **Risk:** Low.
  - SQLite sleeps in fractions of a second only where it can. In SQLite 3.41 a Unix build needed `HAVE_USLEEP`, or it slept in whole seconds. By 3.49 it does unless built with `HAVE_NANOSLEEP=0`, and 3.53.3's code is the same. SQLitePCLRaw's Linux build sets neither, so CI's Linux runners should get the short sleeps. Each INSERT's time in the load test's app log would show a whole-second sleep at once.
  - It doesn't help a read-then-write transaction, which SQLite refuses at once to avoid a deadlock (`SQLITE_BUSY_SNAPSHOT`). The sample has none.

### Option 2: A busy timeout as long as the command timeout

The same interceptor, with the busy timeout set from EF Core's command timeout, or else the connection's `Default Timeout` (30 seconds), and 0 ("no limit") turned into SQLite's longest wait.

- **Trade-offs:** SQLite does all the waiting. But each statement gets the whole timeout. A `SaveChanges` that EF Core batches into one command of several statements could run for several times its timeout. A timeout set after the connection opened isn't seen either. Microsoft.Data.Sqlite's maintainers decline to set the busy timeout from the command timeout for these reasons (dotnet/efcore#28135).
- **Reversibility:** Easy.
- **Risk:** Medium: it breaks the command timeout's meaning for any command of more than one statement. This branch built it first; review found the issue.

### Option 3: Queue the app's writes behind an async lock

A `SemaphoreSlim`, shared by every `DbContext` as a singleton, is taken around `SaveChanges`. Only one write runs at a time, and the others wait without blocking a thread.

- **Trade-offs:** Exact waits and no blocked threads. It covers only writes through `SaveChanges` in this process. `ExecuteUpdate`, `ExecuteDelete`, raw SQL, a second process or a tool on the same file would still meet the 150 ms sleep. Every new way of writing must remember the lock.
- **Reversibility:** Easy.
- **Risk:** Medium: a write path that skips the lock brings the pause back silently.

### Option 4: `synchronous=NORMAL`

SQLite syncs its log only at checkpoints, so commits are fast and meet less often.

- **Trade-offs:** SQLite says WAL mode with `NORMAL` can't corrupt the database, but a committed transaction "might roll back following a power loss or system crash". A bookmark the API answered `201 Created` for could vanish. And writes that meet would still pay the 150 ms sleep, just less often.
- **Reversibility:** Easy.
- **Risk:** Medium:
  - it trades durability for speed, which is a product decision;
  - it hides the 150 ms pause instead of removing it.

### Option 5: Change the measurement

Raise the budget, leave a warm-up out of the stats, or run longer for more samples.

- **Trade-offs:** No code change. The evidence rules out warm-up and sample size, and a higher budget would accept a pause that a user would feel.
- **Reversibility:** Easy.
- **Risk:** High: it works around the defect (CRF-001).

## Recommendation

Option 1. It removes the 150 ms pause for every connection and every kind of write, with the mechanism SQLite provides for this, and it keeps the command timeout Microsoft.Data.Sqlite's.

## Decision

Option 1, decided in auto mode (ADR-0035) on 2026-11-15, while answering the red load-test runs on the branches of PR 70, PR 73 and the release PR, PR 10.

**Update (2026-11-25):** the sample moved to SQL Server (GAP-025, ADR-0098), so its interceptor and `SqliteBusyTimeoutTests` are gone. The finding still holds for any app on SQLite, a MAUI or desktop app's device database, and `docs/database-guide.md` keeps the call for them.

## Consequences

- New: `sample/src/Bookmarks.Infrastructure/SqliteBusyTimeoutInterceptor.cs`, registered in `AddBookmarksInfrastructure`.
- New: `SqliteBusyTimeoutTests` in the integration tests. They read `PRAGMA busy_timeout` on connections opened, synchronously and not, through the app's own registration.
- Measured on Windows, with another connection holding the write lock for 20 ms, over 20 saves each:
  - before: 154 to 160 ms;
  - after: about 46 ms. Windows sleeps in steps of about 15 ms.
  - Not yet measured on Linux. The PR's own Performance runs show it.
- The load test and its budget are unchanged (ADR-0062): it still measures the API and its SQLite file on a shared runner. A slow runner still shows in its slow commits and reads, but writes that meet one no longer pay 150 ms on top. Whether that keeps every slow runner within budget is expected, not proven: a runner slower than the red ones could still fail it.
- The database guide (`docs/database-guide.md`) tells an app that uses SQLite how to do the same. An app doesn't get the sample, so the guide states the call and the value itself. No kit rule checks it: the guide picks SQLite only for a device's own data, where writes rarely meet, and a rule would need a check that reads an app's EF Core setup.

## Pillars affected

- **Performance Efficiency:** a write that meets another waits about as long as the lock is held, not 150 ms or more.
- **Reliability:** the command timeout still bounds each command, give or take about a second per statement more than before. The load test's POST p95 is expected to stay within budget on runners like the red ones; the PR's Performance runs are the first evidence.
- **Operational Excellence:** the evidence came from the run artifacts ADR-0062 keeps: Locust's stats and the app's log.

## Sources

- https://learn.microsoft.com/dotnet/standard/data/sqlite/database-errors, retrieved 2026-11-15
- https://learn.microsoft.com/dotnet/standard/data/sqlite/interop, retrieved 2026-11-15
- https://learn.microsoft.com/dotnet/standard/data/sqlite/async, retrieved 2026-11-15
- https://raw.githubusercontent.com/dotnet/efcore/release/10.0/src/Microsoft.Data.Sqlite.Core/SqliteDataReader.cs, retrieved 2026-11-15
- https://github.com/dotnet/efcore/issues/28135, retrieved 2026-11-15
- https://www.sqlite.org/c3ref/busy_timeout.html, retrieved 2026-11-15
- https://www.sqlite.org/pragma.html#pragma_synchronous, retrieved 2026-11-15
- `sqliteDefaultBusyCallback` in SQLite's `src/main.c` at version-3.41.0, version-3.49.1 and version-3.53.3 (https://github.com/sqlite/sqlite), retrieved 2026-11-15
- https://github.com/ericsink/cb/blob/cd2922b8867e4360f0976601414bd24a3ad613d8/bld/cb.cs (e_sqlite3's compile options), retrieved 2026-11-15
- GitHub Actions runs 43504641754, 43503299942, 43541215632 and 43561350708 (red), and 43542125655, 43607986383, 43644689740, 43647654284, 43675018136 and 43687112597 (green), with their `load-test-results` artifacts, retrieved 2026-11-15
