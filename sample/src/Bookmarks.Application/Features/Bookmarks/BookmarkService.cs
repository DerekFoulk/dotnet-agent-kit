using Bookmarks.Contracts;

namespace Bookmarks.Application.Features.Bookmarks;

/// <summary>The outcome of adding a bookmark: the saved bookmark, or that its URL is already saved.</summary>
public sealed record AddBookmarkResult(BookmarkResponse? Bookmark, bool AlreadyExists);

/// <summary>Bookmark use cases.</summary>
public sealed class BookmarkService(IBookmarkRepository repository, TimeProvider timeProvider)
{
    private readonly IBookmarkRepository _repository = repository;
    private readonly TimeProvider _timeProvider = timeProvider;

    public Task<AddBookmarkResult> AddAsync(CreateBookmarkRequest request, CancellationToken cancellationToken)
    {
        _ = (_repository, _timeProvider, request, cancellationToken);
        return Task.FromResult(new AddBookmarkResult(null, false));
    }

    public Task<BookmarkResponse?> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        _ = (_repository, id, cancellationToken);
        return Task.FromResult<BookmarkResponse?>(null);
    }

    public Task<IReadOnlyList<BookmarkResponse>> ListAsync(CancellationToken cancellationToken)
    {
        _ = (_repository, cancellationToken);
        return Task.FromResult<IReadOnlyList<BookmarkResponse>>([]);
    }
}
