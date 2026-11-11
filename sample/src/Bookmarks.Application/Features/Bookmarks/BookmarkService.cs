using Bookmarks.Contracts;
using Bookmarks.Domain;

namespace Bookmarks.Application.Features.Bookmarks;

/// <summary>The outcome of adding a bookmark: the saved bookmark, or that its URL is already saved.</summary>
public sealed record AddBookmarkResult(BookmarkResponse? Bookmark, bool AlreadyExists);

/// <summary>One page of bookmarks, and whether another page follows it.</summary>
public sealed record BookmarkListResult(IReadOnlyList<BookmarkResponse> Items, bool HasMore);

/// <summary>Bookmark use cases.</summary>
public sealed class BookmarkService(IBookmarkRepository repository, TimeProvider timeProvider)
{
    private readonly IBookmarkRepository _repository = repository;
    private readonly TimeProvider _timeProvider = timeProvider;

    /// <summary>Saves a bookmark for the given user (SEC-009).</summary>
    public async Task<AddBookmarkResult> AddAsync(string ownerId, CreateBookmarkRequest request, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);
        // The domain checks the request before anything uses it (CRF-006); the lookup then uses the checked URL.
        Bookmark bookmark = Bookmark.Create(ownerId, request.Url, request.Title, _timeProvider.GetUtcNow());
        Bookmark? existing = await _repository.FindByUrlAsync(ownerId, bookmark.Url, cancellationToken).ConfigureAwait(false);
        if (existing is not null)
        {
            return new AddBookmarkResult(null, AlreadyExists: true);
        }

        await _repository.AddAsync(bookmark, cancellationToken).ConfigureAwait(false);
        return new AddBookmarkResult(ToResponse(bookmark), AlreadyExists: false);
    }

    /// <summary>The user's bookmark with this id, or null when they have none: another user's bookmark is null too.</summary>
    public async Task<BookmarkResponse?> GetAsync(string ownerId, Guid id, CancellationToken cancellationToken)
    {
        Bookmark? bookmark = await _repository.FindAsync(ownerId, id, cancellationToken).ConfigureAwait(false);
        return bookmark is null ? null : ToResponse(bookmark);
    }

    /// <summary>The largest page a caller may ask for (API-004).</summary>
    public const int MaxPageSize = 100;

    /// <summary>The deepest offset: offset paging reads and skips every earlier row (Azure's API implementation guide).</summary>
    public const int MaxOffset = 10_000;

    /// <summary>One page of the user's own bookmarks.</summary>
    public async Task<BookmarkListResult> ListAsync(string ownerId, int offset, int limit, CancellationToken cancellationToken)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(offset);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(offset, MaxOffset);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(limit);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(limit, MaxPageSize);

        // One row more than the page shows whether another page follows, without counting every row. A next page that
        // would start past MaxOffset couldn't be read, so this page is the last one reachable.
        IReadOnlyList<Bookmark> bookmarks = await _repository.ListAsync(ownerId, offset, limit + 1, cancellationToken).ConfigureAwait(false);
        bool hasMore = bookmarks.Count > limit && offset + limit <= MaxOffset;
        return new BookmarkListResult([.. bookmarks.Take(limit).Select(ToResponse)], hasMore);
    }

    private static BookmarkResponse ToResponse(Bookmark bookmark) =>
        new(bookmark.Id, bookmark.Url, bookmark.Title, bookmark.CreatedAt);
}
