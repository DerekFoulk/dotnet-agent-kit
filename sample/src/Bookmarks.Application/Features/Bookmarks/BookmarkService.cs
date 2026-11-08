using Bookmarks.Contracts;
using Bookmarks.Domain;

namespace Bookmarks.Application.Features.Bookmarks;

/// <summary>The outcome of adding a bookmark: the saved bookmark, or that its URL is already saved.</summary>
public sealed record AddBookmarkResult(BookmarkResponse? Bookmark, bool AlreadyExists);

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

    public async Task<IReadOnlyList<BookmarkResponse>> ListAsync(CancellationToken cancellationToken)
    {
        IReadOnlyList<Bookmark> bookmarks = await _repository.ListAsync(0, int.MaxValue, cancellationToken).ConfigureAwait(false);
        return [.. bookmarks.Select(ToResponse)];
    }

    private static BookmarkResponse ToResponse(Bookmark bookmark) =>
        new(bookmark.Id, bookmark.Url, bookmark.Title, bookmark.CreatedAt);
}
