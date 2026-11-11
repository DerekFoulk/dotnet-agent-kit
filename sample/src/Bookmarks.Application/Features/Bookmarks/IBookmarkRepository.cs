using Bookmarks.Domain;

namespace Bookmarks.Application.Features.Bookmarks;

/// <summary>
/// Stores bookmarks. Infrastructure implements it. Every read takes the owner's id and sees only that user's
/// bookmarks (SEC-009), so no caller can reach another user's by guessing an id or a URL.
/// </summary>
public interface IBookmarkRepository
{
    Task<Bookmark?> FindAsync(string ownerId, Guid id, CancellationToken cancellationToken);

    /// <summary>
    /// The owner's bookmark whose stored URL is exactly this one's text, so pass a URL in its stored form: a
    /// bookmark's own <see cref="Bookmark.Url"/>, from <see cref="Bookmark.Create"/>.
    /// </summary>
    Task<Bookmark?> FindByUrlAsync(string ownerId, Uri url, CancellationToken cancellationToken);

    /// <summary>One page of the owner's bookmarks, in a stable order: <paramref name="limit"/> of them from <paramref name="offset"/>.</summary>
    Task<IReadOnlyList<Bookmark>> ListAsync(string ownerId, int offset, int limit, CancellationToken cancellationToken);

    Task AddAsync(Bookmark bookmark, CancellationToken cancellationToken);
}
