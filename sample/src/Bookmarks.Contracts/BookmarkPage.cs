namespace Bookmarks.Contracts;

// The XML comments on this type are the OpenAPI document's descriptions, written for the API's callers and each on
// one line, as CreateBookmarkRequest.cs says.
/// <summary>One page of bookmarks, in an order that stays the same from page to page.</summary>
/// <param name="Items">The bookmarks on this page.</param>
/// <param name="NextLink">The next page, or null where paging ends: on the last page, or at the offset cap, even when more bookmarks exist.</param>
public sealed record BookmarkPage(IReadOnlyList<BookmarkResponse> Items, Uri? NextLink);
