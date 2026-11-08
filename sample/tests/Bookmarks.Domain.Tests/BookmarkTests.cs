namespace Bookmarks.Domain.Tests;

public sealed class BookmarkTests
{
    private static readonly DateTimeOffset s_now = new(2026, 11, 4, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void CreateKeepsTheUrlAndTrimsTheTitle()
    {
        Bookmark bookmark = Bookmark.Create(new Uri("https://example.com/articles/1"), "  Clean code  ", s_now);

        bookmark.Id.Should().NotBe(Guid.Empty);
        bookmark.Url.Should().Be(new Uri("https://example.com/articles/1"));
        bookmark.Title.Should().Be("Clean code");
        bookmark.CreatedAt.Should().Be(s_now);
    }

    [Theory]
    [InlineData("ftp://example.com/file")]
    [InlineData("mailto:someone@example.com")]
    public void CreateRejectsAUrlThatIsNotHttpOrHttps(string address)
    {
        Action create = () => Bookmark.Create(new Uri(address), "Title", s_now);

        create.Should().Throw<ArgumentException>().WithParameterName("url");
    }

    [Fact]
    public void CreateRejectsARelativeUrl()
    {
        Action create = () => Bookmark.Create(new Uri("/articles/1", UriKind.Relative), "Title", s_now);

        create.Should().Throw<ArgumentException>().WithParameterName("url");
    }

    [Fact]
    public void IdsSortInTheOrderTheBookmarksWereCreated()
    {
        // Review 1 of PR 22: lists are ordered by Id (API-004), so a time-ordered Id (UUID version 7) makes that the
        // creation order, and a new bookmark lands on the last page instead of shifting a random one. Ordinal string
        // order is how the database compares them.
        List<string> ids = [.. Enumerable.Range(0, 20)
            .Select(minute => Bookmark.Create(new Uri($"https://example.com/{minute}"), "Title", s_now.AddMinutes(minute)).Id.ToString())];

        ids.Should().BeInAscendingOrder(StringComparer.Ordinal);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void CreateRejectsABlankTitle(string blankTitle)
    {
        Action create = () => Bookmark.Create(new Uri("https://example.com/"), blankTitle, s_now);

        create.Should().Throw<ArgumentException>().WithParameterName("title");
    }
}
