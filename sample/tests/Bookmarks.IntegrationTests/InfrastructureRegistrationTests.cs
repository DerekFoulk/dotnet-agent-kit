using Bookmarks.Domain;
using Bookmarks.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.IntegrationTests;

/// <summary>How the app registers its database: the provider and its settings, read without opening a connection.</summary>
public sealed class InfrastructureRegistrationTests
{
    // Never opened: these tests read the registration only.
    private const string UnusedConnectionString = "Server=localhost;Database=Bookmarks";

    [Fact]
    public void TheDatabaseIsSqlServerAndRetriesTransientFailures()
    {
        // DAT-007: a connection to a server database retries transient failures with its provider's execution strategy.
        using ServiceProvider services = new ServiceCollection().AddBookmarksInfrastructure(UnusedConnectionString).BuildServiceProvider();
        using IServiceScope scope = services.CreateScope();
        DatabaseFacade database = scope.ServiceProvider.GetRequiredService<BookmarksDbContext>().Database;

        database.ProviderName.Should().Be("Microsoft.EntityFrameworkCore.SqlServer");
        database.CreateExecutionStrategy().RetriesOnFailure.Should().BeTrue();
    }

    [Fact]
    public void TheModelHasNoChangeThatNoMigrationCovers()
    {
        // DAT-002, DAT-017: a change to the model without its migration fails here, long before a deployment would
        // find it. It compares the model with the last migration's snapshot, so it needs no database.
        using ServiceProvider services = new ServiceCollection().AddBookmarksInfrastructure(UnusedConnectionString).BuildServiceProvider();
        using IServiceScope scope = services.CreateScope();
        DatabaseFacade database = scope.ServiceProvider.GetRequiredService<BookmarksDbContext>().Database;

        database.HasPendingModelChanges().Should().BeFalse("every change to the model comes with its migration (dotnet ef migrations add)");
    }

    [Fact]
    public void TheModelKeysOnIdRequiresEveryFieldCapsTheTitleAndIndexesEachOwnersPages()
    {
        // Mutation testing (PR 23): EF finds "Id" as the key by convention, and no behaviour test noticed when a line
        // of OnModelCreating was removed. These are the schema's promises. EF caches a built model for the whole
        // process; a fresh service provider builds it again, so a mutated OnModelCreating is really run (Stryker reuses
        // one test process across mutants).
        DbContextOptions<BookmarksDbContext> uncached = new DbContextOptionsBuilder<BookmarksDbContext>()
            .UseSqlServer(UnusedConnectionString).EnableServiceProviderCaching(false).Options;
        using BookmarksDbContext db = new(uncached);
        // The design-time model, which keeps SQL Server's index settings (the included columns) the read-optimized one drops.
        Microsoft.EntityFrameworkCore.Metadata.IEntityType bookmark = db.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(Bookmark))!;

        bookmark.FindPrimaryKey()!.Properties.Select(p => p.Name).Should().Equal(nameof(Bookmark.Id));
        bookmark.FindProperty(nameof(Bookmark.OwnerId))!.IsNullable.Should().BeFalse();
        bookmark.FindProperty(nameof(Bookmark.OwnerId))!.GetMaxLength().Should().Be(Bookmark.MaxOwnerIdLength);
        bookmark.FindProperty(nameof(Bookmark.Url))!.IsNullable.Should().BeFalse();
        bookmark.FindProperty(nameof(Bookmark.Url))!.GetMaxLength().Should().Be(Bookmark.MaxUrlLength);
        bookmark.FindProperty(nameof(Bookmark.Title))!.IsNullable.Should().BeFalse();
        bookmark.FindProperty(nameof(Bookmark.Title))!.GetMaxLength().Should().Be(Bookmark.MaxTitleLength);
        bookmark.FindProperty(nameof(Bookmark.CreatedAt))!.IsNullable.Should().BeFalse();
        // Every read filters by owner first (SEC-009), then pages in creation order, so the table is clustered that way.
        // Not on the key: SQL Server sorts a UUID version 7 by its random bits, so each insert would land at random.
        Microsoft.EntityFrameworkCore.Metadata.IIndex index = bookmark.GetIndexes().Should().ContainSingle().Subject;
        index.Properties.Select(p => p.Name).Should().Equal(nameof(Bookmark.OwnerId), nameof(Bookmark.CreatedAt));
        index.IsClustered().Should().BeTrue();
        bookmark.FindPrimaryKey()!.IsClustered().Should().BeFalse();
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void InfrastructureNeedsAConnectionString(string blank)
    {
        // Mutation testing (PR 23): without the guard, a blank connection string failed only at the first query.
        Action add = () => Microsoft.Extensions.DependencyInjection.InfrastructureServiceCollectionExtensions
            .AddBookmarksInfrastructure(new Microsoft.Extensions.DependencyInjection.ServiceCollection(), blank);

        add.Should().Throw<ArgumentException>().WithParameterName("connectionString");
    }
}
