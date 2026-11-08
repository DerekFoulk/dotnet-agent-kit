namespace Bookmarks.Domain;

public sealed class Bookmark
{
    private Bookmark(Guid id, Uri url, string title, DateTimeOffset createdAt)
    {
        Id = id;
        Url = url;
        Title = title;
        CreatedAt = createdAt;
    }

    public Guid Id { get; }

    public Uri Url { get; }

    public string Title { get; }

    public DateTimeOffset CreatedAt { get; }

    public static Bookmark Create(Uri url, string title, DateTimeOffset createdAt)
    {
        ArgumentNullException.ThrowIfNull(url);
        if (!url.IsAbsoluteUri || (url.Scheme != Uri.UriSchemeHttp && url.Scheme != Uri.UriSchemeHttps))
        {
            throw new ArgumentException("A bookmark needs an absolute http or https URL.", nameof(url));
        }

        ArgumentException.ThrowIfNullOrWhiteSpace(title);
        // A UUID version 7 starts with its creation time (to the millisecond), so on SQLite ordering by Id is creation
        // order. It needs a time from 1970 on; createdAt comes from TimeProvider.
        return new Bookmark(Guid.CreateVersion7(createdAt), url, title.Trim(), createdAt);
    }
}
