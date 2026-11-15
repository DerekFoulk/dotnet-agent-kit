using Microsoft.EntityFrameworkCore;

namespace RawSqlInterpolation;

// DAT-010: a caller's value interpolated into a Raw method is SQL injection, which EF Core's analyzer EF1002 reports.
internal sealed class Store(DbContextOptions<Store> options) : DbContext(options)
{
    internal Task<int> CountTitledAsync(string title, CancellationToken cancellationToken) =>
        Database.SqlQueryRaw<int>($"SELECT COUNT(*) AS Value FROM Bookmarks WHERE Title = '{title}'").SingleAsync(cancellationToken);

    internal Task<int> DeleteTitledAsync(string title, CancellationToken cancellationToken) =>
        Database.ExecuteSqlRawAsync($"DELETE FROM Bookmarks WHERE Title = '{title}'", cancellationToken);
}
