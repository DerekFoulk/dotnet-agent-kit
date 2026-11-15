using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace Microsoft.Extensions.DependencyInjection;

/// <summary>Registers the bookmarks database and repository.</summary>
public static class InfrastructureServiceCollectionExtensions
{
    // It holds no state, so every DbContext shares one, as EF Core's interceptor docs suggest.
    private static readonly SqliteBusyTimeoutInterceptor s_busyTimeout = new();

    public static IServiceCollection AddBookmarksInfrastructure(this IServiceCollection services, string connectionString)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(connectionString);
        services.AddDbContext<BookmarksDbContext>(options => options.UseSqlite(connectionString).AddInterceptors(s_busyTimeout));
        services.AddScoped<IBookmarkRepository, EfBookmarkRepository>();
        // Readiness: /health reports unhealthy while the database can't be reached (OPS-002).
        services.AddHealthChecks().AddDbContextCheck<BookmarksDbContext>();
        return services;
    }
}
