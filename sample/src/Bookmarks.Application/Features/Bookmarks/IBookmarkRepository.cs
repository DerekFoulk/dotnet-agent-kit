using Bookmarks.Domain;

namespace Bookmarks.Application.Features.Bookmarks;

/// <summary>Stores bookmarks. Infrastructure implements it.</summary>
public interface IBookmarkRepository
{
    Task<Bookmark?> FindAsync(Guid id, CancellationToken cancellationToken);

    Task<Bookmark?> FindByUrlAsync(Uri url, CancellationToken cancellationToken);

    /// <summary>One page of bookmarks, in a stable order: <paramref name="limit"/> of them from <paramref name="offset"/>.</summary>
    Task<IReadOnlyList<Bookmark>> ListAsync(int offset, int limit, CancellationToken cancellationToken);

    Task AddAsync(Bookmark bookmark, CancellationToken cancellationToken);
}
