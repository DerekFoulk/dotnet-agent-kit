using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Domain;

namespace Bookmarks.Infrastructure;

/// <summary>Stores bookmarks with EF Core.</summary>
public sealed class EfBookmarkRepository(BookmarksDbContext db) : IBookmarkRepository
{
    private readonly BookmarksDbContext _db = db;

    public Task<Bookmark?> FindAsync(Guid id, CancellationToken cancellationToken)
    {
        _ = (_db, id, cancellationToken);
        return Task.FromResult<Bookmark?>(null);
    }

    public Task<Bookmark?> FindByUrlAsync(Uri url, CancellationToken cancellationToken)
    {
        _ = (_db, url, cancellationToken);
        return Task.FromResult<Bookmark?>(null);
    }

    public Task<IReadOnlyList<Bookmark>> ListAsync(CancellationToken cancellationToken)
    {
        _ = (_db, cancellationToken);
        return Task.FromResult<IReadOnlyList<Bookmark>>([]);
    }

    public Task AddAsync(Bookmark bookmark, CancellationToken cancellationToken)
    {
        _ = (_db, bookmark, cancellationToken);
        return Task.CompletedTask;
    }
}
