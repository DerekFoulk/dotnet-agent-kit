namespace Bookmarks.Contracts;

// The XML comments on this type are the OpenAPI document's descriptions, written for the API's callers and each on
// one line, as CreateBookmarkRequest.cs says.
/// <summary>A saved bookmark.</summary>
/// <param name="Id">The bookmark's id.</param>
/// <param name="Url">The saved link.</param>
/// <param name="Title">The bookmark's title, trimmed.</param>
/// <param name="CreatedAt">When it was saved.</param>
public sealed record BookmarkResponse(Guid Id, Uri Url, string Title, DateTimeOffset CreatedAt);
