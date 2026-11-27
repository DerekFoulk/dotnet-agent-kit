using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace Microsoft.Extensions.DependencyInjection;

/// <summary>Registers the bookmarks database and repository.</summary>
public static class InfrastructureServiceCollectionExtensions
{
    /// <summary>Adds the bookmarks database, on SQL Server, and its repository.</summary>
    /// <param name="services">The app's services.</param>
    /// <param name="connectionString">The SQL Server connection string.</param>
    /// <returns>The same services, to chain more calls.</returns>
    public static IServiceCollection AddBookmarksInfrastructure(this IServiceCollection services, string connectionString)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(connectionString);
        // Transient failures are retried with SQL Server's own execution strategy (DAT-007). The service makes each
        // bookmark's key itself, so a retried commit can't add a second row: it fails on the key instead.
        services.AddDbContext<BookmarksDbContext>(options => options.UseSqlServer(connectionString, sqlServer => sqlServer.EnableRetryOnFailure()));
        services.AddScoped<IBookmarkRepository, EfBookmarkRepository>();
        // Readiness: /health reports unhealthy while the database can't be reached (OPS-002).
        services.AddHealthChecks().AddDbContextCheck<BookmarksDbContext>();
        return services;
    }
}
