using Bookmarks.Domain;

namespace Bookmarks.Application.Features.Bookmarks;

/// <summary>Stores bookmarks. Infrastructure implements it.</summary>
public interface IBookmarkRepository
{
    Task<Bookmark?> FindAsync(Guid id, CancellationToken cancellationToken);

    Task<Bookmark?> FindByUrlAsync(Uri url, CancellationToken cancellationToken);

    Task<IReadOnlyList<Bookmark>> ListAsync(CancellationToken cancellationToken);

    Task AddAsync(Bookmark bookmark, CancellationToken cancellationToken);
}
