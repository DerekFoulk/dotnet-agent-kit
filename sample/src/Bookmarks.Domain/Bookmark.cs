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
        return new Bookmark(Guid.NewGuid(), url, title.Trim(), createdAt);
    }
}
