using Bookmarks.Contracts;

namespace Bookmarks.Application.Features.Bookmarks;

/// <summary>The outcome of adding a bookmark: the saved bookmark, or that its URL is already saved.</summary>
public sealed record AddBookmarkResult(BookmarkResponse? Bookmark, bool AlreadyExists);
