using System.Data.Common;
using Bookmarks.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.IntegrationTests;

/// <summary>
/// How long a connection the app opens waits when another connection holds SQLite's write lock. Microsoft.Data.Sqlite
/// answers a locked database by sleeping a fixed 150 ms before it tries again, so a write that found the lock taken
/// took at least 150 ms however soon the lock was free: the load test's POST p95 of 110 to 190 ms (ADR-0069). SQLite's
/// own busy timeout has the write wait for the lock itself and go on as soon as it's free.
/// </summary>
public sealed class SqliteBusyTimeoutTests
{
    [Fact]
    public async Task OpenConnectionAsyncWaitsForALockedDatabaseAsLongAsTheConnectionsDefaultTimeout()
    {
        long busyTimeout = await BusyTimeoutAfterOpenAsync("DataSource=:memory:;Default Timeout=7");

        busyTimeout.Should().Be(7_000, "a command may run for the connection's Default Timeout, 7 seconds");
    }

    // Opens the database connection through the app's own registration, then asks SQLite how long it waits for a lock.
    private static async Task<long> BusyTimeoutAfterOpenAsync(string connectionString)
    {
        await using ServiceProvider services = new ServiceCollection().AddBookmarksInfrastructure(connectionString).BuildServiceProvider();
        await using AsyncServiceScope scope = services.CreateAsyncScope();
        BookmarksDbContext db = scope.ServiceProvider.GetRequiredService<BookmarksDbContext>();
        await db.Database.OpenConnectionAsync(TestContext.Current.CancellationToken);
        return await ReadBusyTimeoutAsync(db.Database.GetDbConnection());
    }

    private static async Task<long> ReadBusyTimeoutAsync(DbConnection connection)
    {
        await using DbCommand command = connection.CreateCommand();
        command.CommandText = "PRAGMA busy_timeout";
        return (long)(await command.ExecuteScalarAsync(TestContext.Current.CancellationToken))!;
    }
}
