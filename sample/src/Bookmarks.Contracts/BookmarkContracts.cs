namespace Bookmarks.Contracts;

/// <summary>A request to save a bookmark.</summary>
public sealed record CreateBookmarkRequest(Uri Url, string Title);

/// <summary>A saved bookmark.</summary>
public sealed record BookmarkResponse(Guid Id, Uri Url, string Title, DateTimeOffset CreatedAt);

/// <summary>One page of bookmarks, with a link to the next page, or null on the last.</summary>
public sealed record BookmarkPage(IReadOnlyList<BookmarkResponse> Items, Uri? NextLink);
