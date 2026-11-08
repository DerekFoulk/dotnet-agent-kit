namespace Bookmarks.Contracts;

/// <summary>A request to save a bookmark.</summary>
public sealed record CreateBookmarkRequest(Uri Url, string Title);

/// <summary>A saved bookmark.</summary>
public sealed record BookmarkResponse(Guid Id, Uri Url, string Title, DateTimeOffset CreatedAt);

/// <summary>
/// One page of bookmarks, with a link to the next page. It's null on the last page, and on the last page the offset
/// cap allows even when more bookmarks exist (API-004).
/// </summary>
public sealed record BookmarkPage(IReadOnlyList<BookmarkResponse> Items, Uri? NextLink);
