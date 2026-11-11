using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Domain;
using Microsoft.EntityFrameworkCore;

namespace Bookmarks.Infrastructure;

/// <summary>Stores bookmarks with EF Core. Every read filters by the owner in the query itself (SEC-009).</summary>
public sealed class EfBookmarkRepository(BookmarksDbContext db) : IBookmarkRepository
{
    private readonly BookmarksDbContext _db = db;

    public Task<Bookmark?> FindAsync(string ownerId, Guid id, CancellationToken cancellationToken) =>
        Owned(ownerId).FirstOrDefaultAsync(b => b.Id == id, cancellationToken);

    public Task<Bookmark?> FindByUrlAsync(string ownerId, Uri url, CancellationToken cancellationToken) =>
        Owned(ownerId).FirstOrDefaultAsync(b => b.Url == url, cancellationToken);

    // Paged in the database, ordered by the key so pages never overlap. (SQLite can't order by a DateTimeOffset.)
    public async Task<IReadOnlyList<Bookmark>> ListAsync(string ownerId, int offset, int limit, CancellationToken cancellationToken) =>
        await Owned(ownerId).OrderBy(b => b.Id).Skip(offset).Take(limit)
            .ToListAsync(cancellationToken).ConfigureAwait(false);

    public async Task AddAsync(Bookmark bookmark, CancellationToken cancellationToken)
    {
        _db.Bookmarks.Add(bookmark);
        await _db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    private IQueryable<Bookmark> Owned(string ownerId) => _db.Bookmarks.AsNoTracking().Where(b => b.OwnerId == ownerId);
}
