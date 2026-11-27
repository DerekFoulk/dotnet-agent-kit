using Bookmarks.Infrastructure;
using Bookmarks.TestDatabase;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Bookmarks.IntegrationTests;

/// <summary>
/// The app's migrations on SQL Server (DAT-002, DAT-017). Every other test here applies them; this one takes them back
/// off, as a developer does to redo a migration locally. Production rolls forward instead (docs/standards/data.md).
/// </summary>
public sealed class MigrationTests
{
    [Fact]
    public void TheMigrationsRollBackToAnEmptyDatabase()
    {
        using BookmarksDbContext db = new(new DbContextOptionsBuilder<BookmarksDbContext>().UseSqlServer(SqlServerTestDatabase.Create()).Options);

        db.GetService<IMigrator>().Migrate(Migration.InitialDatabase);

        db.Database.GetAppliedMigrations().Should().BeEmpty();
        db.Database.SqlQueryRaw<int>("SELECT COUNT(*) AS [Value] FROM sys.tables WHERE name = 'Bookmarks'").AsEnumerable().Single()
            .Should().Be(0, "the last migration's Down drops the table its Up created");
    }
}
