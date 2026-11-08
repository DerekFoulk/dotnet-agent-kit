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

    public async Task<AddBookmarkResult> AddAsync(CreateBookmarkRequest request, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);
        Bookmark? existing = await _repository.FindByUrlAsync(request.Url, cancellationToken).ConfigureAwait(false);
        if (existing is not null)
        {
            return new AddBookmarkResult(null, AlreadyExists: true);
        }

        Bookmark bookmark = Bookmark.Create(request.Url, request.Title, _timeProvider.GetUtcNow());
        await _repository.AddAsync(bookmark, cancellationToken).ConfigureAwait(false);
        return new AddBookmarkResult(ToResponse(bookmark), AlreadyExists: false);
    }

    public async Task<BookmarkResponse?> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        Bookmark? bookmark = await _repository.FindAsync(id, cancellationToken).ConfigureAwait(false);
        return bookmark is null ? null : ToResponse(bookmark);
    }

    public async Task<BookmarkListResult> ListAsync(int offset, int limit, CancellationToken cancellationToken)
    {
        // One row more than the page shows whether another page follows, without counting every row.
        IReadOnlyList<Bookmark> bookmarks = await _repository.ListAsync(offset, limit + 1, cancellationToken).ConfigureAwait(false);
        return new BookmarkListResult([.. bookmarks.Take(limit).Select(ToResponse)], HasMore: bookmarks.Count > limit);
    }

    private static BookmarkResponse ToResponse(Bookmark bookmark) =>
        new(bookmark.Id, bookmark.Url, bookmark.Title, bookmark.CreatedAt);
}
