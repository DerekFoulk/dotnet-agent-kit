using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace Microsoft.Extensions.DependencyInjection;

/// <summary>Registers the bookmarks database and repository.</summary>
public static class InfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddBookmarksInfrastructure(this IServiceCollection services, string connectionString)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(connectionString);
        services.AddDbContext<BookmarksDbContext>(options => options.UseSqlite(connectionString));
        services.AddScoped<IBookmarkRepository, EfBookmarkRepository>();
        return services;
    }
}
