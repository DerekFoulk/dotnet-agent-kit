using Bookmarks.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
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
}
