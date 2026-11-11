using System.ComponentModel.DataAnnotations;

namespace Bookmarks.Contracts;

/// <summary>
/// A request to save a bookmark. The API checks it against these attributes before the handler runs (SEC-010,
/// API-006). The limits are the domain's (Bookmark.MaxTitleLength and MaxUrlLength); this project can't reference
/// the domain, so the functional tests check both edges of each limit against it.
/// </summary>
public sealed record CreateBookmarkRequest(
    [property: Required, UriLength(CreateBookmarkRequest.MaxUrlLength)] Uri Url,
    [property: Required, MaxLength(CreateBookmarkRequest.MaxTitleLength)] string Title)
{
    /// <summary>The longest URL the API accepts.</summary>
    public const int MaxUrlLength = 2048;

    /// <summary>The longest title the API accepts.</summary>
    public const int MaxTitleLength = 500;
}

/// <summary>A saved bookmark.</summary>
public sealed record BookmarkResponse(Guid Id, Uri Url, string Title, DateTimeOffset CreatedAt);

/// <summary>
/// One page of bookmarks, with a link to the next page. It's null on the last page, and on the last page the offset
/// cap allows even when more bookmarks exist (API-004).
/// </summary>
public sealed record BookmarkPage(IReadOnlyList<BookmarkResponse> Items, Uri? NextLink);
