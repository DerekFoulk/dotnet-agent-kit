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
        return new Bookmark(Guid.Empty, url, title, createdAt);
    }
}
