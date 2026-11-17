namespace Bookmarks.Domain;

/// <summary>A link a user saved, with its title: the sample's one aggregate. Make one with <see cref="Create"/>.</summary>
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

    /// <summary>The bookmark's id, a UUID version 7, which starts with its creation time to the millisecond.</summary>
    public Guid Id { get; }

    /// <summary>The user who saved it: their id from the identity provider (the token's sub claim, SEC-009).</summary>
    public string OwnerId { get; }

    /// <summary>The saved link: an absolute http or https URL, in its escaped absolute form.</summary>
    public Uri Url { get; }

    /// <summary>The title the user gave it, trimmed.</summary>
    public string Title { get; }

    /// <summary>When it was saved.</summary>
    public DateTimeOffset CreatedAt { get; }

    /// <summary>Checks a new bookmark's parts and makes the bookmark.</summary>
    /// <param name="id">
    /// Its id, <see cref="Guid.CreateVersion7(DateTimeOffset)"/> of <paramref name="createdAt"/>: the caller makes it,
    /// since its other bits are random and this assembly is pure (ARC-008).
    /// </param>
    /// <param name="ownerId">The saving user's id from the identity provider, at most <see cref="MaxOwnerIdLength"/> characters.</param>
    /// <param name="url">An absolute http or https URL, at most <see cref="MaxUrlLength"/> characters once escaped.</param>
    /// <param name="title">The title, at most <see cref="MaxTitleLength"/> characters once trimmed.</param>
    /// <param name="createdAt">When it's saved, from <see cref="TimeProvider"/>.</param>
    /// <returns>The new bookmark.</returns>
    /// <exception cref="ArgumentException">A part is missing, too long, or not an absolute http or https URL.</exception>
    public static Bookmark Create(Guid id, string ownerId, Uri url, string title, DateTimeOffset createdAt)
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

        // The bookmark keeps the escaped absolute form, the one the limit measures; the database stores exactly that
        // text, so the URL it answers with is always the same and always within the limit. A form that can't be read
        // back (Uri drops bidi controls, which can leave no host) is the caller's bad URL.
        if (!Uri.TryCreate(url.AbsoluteUri, UriKind.Absolute, out Uri? stored))
        {
            throw new ArgumentException("A bookmark needs an absolute http or https URL.", nameof(url));
        }

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

        return new Bookmark(id, ownerId, stored, trimmed, createdAt);
    }
}
