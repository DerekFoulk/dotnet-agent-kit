namespace Bookmarks.Domain;

public sealed class Bookmark
{
    private Bookmark(Guid id, string ownerId, Uri url, string title, DateTimeOffset createdAt)
    {
        Id = id;
        OwnerId = ownerId;
        Url = url;
        Title = title;
        CreatedAt = createdAt;
    }

    /// <summary>
    /// The longest owner id: the token's sub claim, which OpenID Connect caps at 255 ASCII characters (Core 1.0,
    /// section 2).
    /// </summary>
    public const int MaxOwnerIdLength = 255;

    /// <summary>The longest title a bookmark keeps, after trimming (SEC-010).</summary>
    public const int MaxTitleLength = 500;

    /// <summary>
    /// The longest URL a bookmark keeps, in its escaped absolute form (<see cref="Uri.AbsoluteUri"/>), the form it's
    /// stored in: the length browsers and servers commonly support (SEC-010).
    /// </summary>
    public const int MaxUrlLength = 2048;

    public Guid Id { get; }

    /// <summary>The user who saved it: their id from the identity provider (the token's sub claim, SEC-009).</summary>
    public string OwnerId { get; }

    public Uri Url { get; }

    public string Title { get; }

    public DateTimeOffset CreatedAt { get; }

    public static Bookmark Create(string ownerId, Uri url, string title, DateTimeOffset createdAt)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ownerId);
        if (ownerId.Length > MaxOwnerIdLength)
        {
            throw new ArgumentException($"A bookmark's owner id has at most {MaxOwnerIdLength} characters.", nameof(ownerId));
        }

        ArgumentNullException.ThrowIfNull(url);
        if (!url.IsAbsoluteUri || (url.Scheme != Uri.UriSchemeHttp && url.Scheme != Uri.UriSchemeHttps))
        {
            throw new ArgumentException("A bookmark needs an absolute http or https URL.", nameof(url));
        }

        // The bookmark keeps the escaped absolute form, the one the limit measures and the database stores, so the URL
        // it answers with is always the same and always within the limit.
        Uri stored = new(url.AbsoluteUri);
        if (stored.OriginalString.Length > MaxUrlLength)
        {
            throw new ArgumentException($"A bookmark's URL has at most {MaxUrlLength} characters.", nameof(url));
        }

        ArgumentException.ThrowIfNullOrWhiteSpace(title);
        string trimmed = title.Trim();
        if (trimmed.Length > MaxTitleLength)
        {
            throw new ArgumentException($"A bookmark's title has at most {MaxTitleLength} characters.", nameof(title));
        }

        // A UUID version 7 starts with its creation time (to the millisecond), so on SQLite ordering by Id is creation
        // order. It needs a time from 1970 on; createdAt comes from TimeProvider.
        return new Bookmark(Guid.CreateVersion7(createdAt), ownerId, stored, trimmed, createdAt);
    }
}
