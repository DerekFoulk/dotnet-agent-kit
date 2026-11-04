namespace Bookmarks.Contracts;

/// <summary>A request to save a bookmark.</summary>
public sealed record CreateBookmarkRequest(Uri Url, string Title);

/// <summary>A saved bookmark.</summary>
public sealed record BookmarkResponse(Guid Id, Uri Url, string Title, DateTimeOffset CreatedAt);
