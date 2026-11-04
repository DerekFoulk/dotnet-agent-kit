using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Domain;
using Microsoft.EntityFrameworkCore;

namespace Bookmarks.Infrastructure;

/// <summary>Stores bookmarks with EF Core.</summary>
public sealed class EfBookmarkRepository(BookmarksDbContext db) : IBookmarkRepository
{
    private readonly BookmarksDbContext _db = db;

    public Task<Bookmark?> FindAsync(Guid id, CancellationToken cancellationToken) =>
        _db.Bookmarks.AsNoTracking().FirstOrDefaultAsync(b => b.Id == id, cancellationToken);

    public Task<Bookmark?> FindByUrlAsync(Uri url, CancellationToken cancellationToken) =>
        _db.Bookmarks.AsNoTracking().FirstOrDefaultAsync(b => b.Url == url, cancellationToken);

    public async Task<IReadOnlyList<Bookmark>> ListAsync(CancellationToken cancellationToken) =>
        await _db.Bookmarks.AsNoTracking().ToListAsync(cancellationToken).ConfigureAwait(false);

    public async Task AddAsync(Bookmark bookmark, CancellationToken cancellationToken)
    {
        _db.Bookmarks.Add(bookmark);
        await _db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }
}
