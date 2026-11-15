using System.Data.Common;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using SQLitePCL;

namespace Bookmarks.Infrastructure;

/// <summary>
/// Has SQLite wait for a locked database itself, for as long as a command may run, on every connection EF Core opens.
/// SQLite takes one write at a time. Without a busy timeout it fails a second writer at once, and Microsoft.Data.Sqlite
/// then sleeps a fixed 150 ms before trying again, so a write that found the lock taken took at least 150 ms, however
/// soon the lock was free. SQLite's busy timeout has the write go on soon after the lock is free (ADR-0069).
/// </summary>
internal sealed class SqliteBusyTimeoutInterceptor : DbConnectionInterceptor
{
    public override void ConnectionOpened(DbConnection connection, ConnectionEndEventData eventData) =>
        SetBusyTimeout(connection, eventData);

    public override Task ConnectionOpenedAsync(DbConnection connection, ConnectionEndEventData eventData, CancellationToken cancellationToken = default)
    {
        SetBusyTimeout(connection, eventData);
        return Task.CompletedTask;
    }

    // A command runs for EF Core's command timeout when one is set, and for the connection's Default Timeout otherwise.
    // The call is SQLite's own, through the handle Microsoft.Data.Sqlite exposes for it ("Interoperability" in its docs).
    private static void SetBusyTimeout(DbConnection connection, ConnectionEndEventData eventData)
    {
        ArgumentNullException.ThrowIfNull(eventData);
        SqliteConnection sqlite = (SqliteConnection)connection;
        int seconds = eventData.Context?.Database.GetCommandTimeout() ?? sqlite.DefaultTimeout;
        int result = raw.sqlite3_busy_timeout(sqlite.Handle, Milliseconds(seconds));
        SqliteException.ThrowExceptionForRC(result, sqlite.Handle);
    }

    // A timeout of 0 means none to Microsoft.Data.Sqlite, but turns SQLite's busy handler off; SQLite's longest wait
    // is int.MaxValue milliseconds, about 24 days.
    private static int Milliseconds(int seconds) =>
        seconds == 0 ? int.MaxValue : (int)Math.Min(seconds * 1_000L, int.MaxValue);
}
