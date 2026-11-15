using System.Data.Common;
using Bookmarks.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.IntegrationTests;

/// <summary>
/// The busy timeout SQLite has on each connection the app opens: how long it waits itself when another connection holds
/// its write lock. Without one, Microsoft.Data.Sqlite answers a locked database by sleeping a fixed 150 ms before it
/// tries again, so a write that found the lock taken took at least 150 ms however soon the lock was free: the load
/// test's POST p95 of 110 to 190 ms (ADR-0069). With one, SQLite polls the lock and the write goes on about as soon as
/// it's free.
/// </summary>
public sealed class SqliteBusyTimeoutTests
{
    private const string SevenSecondTimeout = "DataSource=:memory:;Default Timeout=7";
    private const long OneSecond = 1_000;

    [Fact]
    public async Task OpenConnectionAsyncWaitsUpToOneSecondForALockedDatabase()
    {
        long busyTimeout = await BusyTimeoutAfterOpenAsync(SevenSecondTimeout);

        busyTimeout.Should().Be(OneSecond, "SQLite waits for the lock itself for a second per statement, and the 7-second command timeout bounds the command");
    }

    [Fact]
    public void OpenConnectionWaitsUpToOneSecondForALockedDatabase()
    {
        // EnsureCreated opens its connection this way, at startup.
        long busyTimeout = BusyTimeoutAfterOpen(SevenSecondTimeout);

        busyTimeout.Should().Be(OneSecond, "SQLite waits for the lock itself for a second per statement, and the 7-second command timeout bounds the command");
    }

    // Each helper opens the database connection through the app's own registration, then asks SQLite how long it
    // waits for a lock.
    private static async Task<long> BusyTimeoutAfterOpenAsync(string connectionString)
    {
        await using ServiceProvider services = AppServices(connectionString);
        await using AsyncServiceScope scope = services.CreateAsyncScope();
        BookmarksDbContext db = scope.ServiceProvider.GetRequiredService<BookmarksDbContext>();
        await db.Database.OpenConnectionAsync(TestContext.Current.CancellationToken);
        await using DbCommand command = BusyTimeoutQuery(db);
        return (long)(await command.ExecuteScalarAsync(TestContext.Current.CancellationToken))!;
    }

    private static long BusyTimeoutAfterOpen(string connectionString)
    {
        using ServiceProvider services = AppServices(connectionString);
        using IServiceScope scope = services.CreateScope();
        BookmarksDbContext db = scope.ServiceProvider.GetRequiredService<BookmarksDbContext>();
        db.Database.OpenConnection();
        using DbCommand command = BusyTimeoutQuery(db);
        return (long)command.ExecuteScalar()!;
    }

    private static ServiceProvider AppServices(string connectionString) =>
        new ServiceCollection().AddBookmarksInfrastructure(connectionString).BuildServiceProvider();

    private static DbCommand BusyTimeoutQuery(BookmarksDbContext db)
    {
        DbCommand command = db.Database.GetDbConnection().CreateCommand();
        command.CommandText = "PRAGMA busy_timeout";
        return command;
    }
}
