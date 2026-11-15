using System.Data.Common;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore.Diagnostics;
using SQLitePCL;

namespace Bookmarks.Infrastructure;

/// <summary>
/// Has SQLite wait for a locked database itself, up to a second per statement, on every connection EF Core opens.
/// SQLite takes one write at a time. Without a busy timeout it fails a second writer at once, and Microsoft.Data.Sqlite
/// then sleeps a fixed 150 ms before trying again, so a write that found the lock taken took at least 150 ms, however
/// soon the lock was free. With it, SQLite polls the lock in short sleeps that grow to 100 ms, so the write goes on
/// about as soon as the lock is free (ADR-0072).
/// </summary>
/// <remarks>
/// The busy timeout is per connection and per statement, while Microsoft.Data.Sqlite's command timeout covers a whole
/// command, which can hold several statements (dotnet/efcore#28135). So it's short: a lock held longer than a second
/// falls back to Microsoft.Data.Sqlite's own retries, which still end at the command timeout, and a statement can run
/// past that timeout by about a second more than the library already allowed. A command timeout is whole seconds, so
/// a second is its smallest step.
/// </remarks>
internal sealed class SqliteBusyTimeoutInterceptor : DbConnectionInterceptor
{
    private const int BusyTimeoutMilliseconds = 1_000;

    public override void ConnectionOpened(DbConnection connection, ConnectionEndEventData eventData)
    {
        ArgumentNullException.ThrowIfNull(connection);
        SetBusyTimeout((SqliteConnection)connection);
    }

    public override Task ConnectionOpenedAsync(DbConnection connection, ConnectionEndEventData eventData, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(connection);
        SetBusyTimeout((SqliteConnection)connection);
        return Task.CompletedTask;
    }

    // SQLite's own call, through the handle Microsoft.Data.Sqlite exposes for it ("Interoperability" in its docs).
    private static void SetBusyTimeout(SqliteConnection connection)
    {
        int result = raw.sqlite3_busy_timeout(connection.Handle, BusyTimeoutMilliseconds);
        // A safety net: SQLite returns an error only for a handle that isn't open, which can't happen right after the
        // connection opened. If it ever did, the app should fail loudly rather than go back to the 150 ms sleeps.
        SqliteException.ThrowExceptionForRC(result, connection.Handle);
    }
}
