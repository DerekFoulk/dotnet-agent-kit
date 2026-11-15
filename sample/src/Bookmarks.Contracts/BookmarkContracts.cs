using System.ComponentModel.DataAnnotations;

namespace Bookmarks.Contracts;

// The API checks a request against these attributes before the handler runs (SEC-010, API-006). The limits are the
// domain's (Bookmark.MaxTitleLength and MaxUrlLength); this project can't reference the domain, so the functional tests
// check both edges of each limit against it. The title is counted here before the domain trims it, so the API is never
// looser than the domain.
//
// The XML comments on these types are the OpenAPI document's descriptions, so they're written for the API's callers,
// and each stays on one line: a line break would be part of the text, and it's \r\n or \n depending on the checkout.
/// <summary>A request to save a bookmark.</summary>
/// <param name="Url">The link to save: an absolute http or https URL.</param>
/// <param name="Title">The bookmark's title.</param>
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
/// <param name="Id">The bookmark's id.</param>
/// <param name="Url">The saved link.</param>
/// <param name="Title">The bookmark's title, trimmed.</param>
/// <param name="CreatedAt">When it was saved.</param>
public sealed record BookmarkResponse(Guid Id, Uri Url, string Title, DateTimeOffset CreatedAt);

/// <summary>One page of bookmarks, oldest first.</summary>
/// <param name="Items">The bookmarks on this page.</param>
/// <param name="NextLink">The next page, or null where paging ends: on the last page, or at the offset cap, even when more bookmarks exist.</param>
public sealed record BookmarkPage(IReadOnlyList<BookmarkResponse> Items, Uri? NextLink);
