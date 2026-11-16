using Bookmarks.Contracts;

namespace Bookmarks.Application.Features.Bookmarks;

/// <summary>One page of bookmarks, and whether another page follows it.</summary>
public sealed record BookmarkListResult(IReadOnlyList<BookmarkResponse> Items, bool HasMore);
