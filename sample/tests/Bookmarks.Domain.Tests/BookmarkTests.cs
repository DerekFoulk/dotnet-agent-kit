namespace Bookmarks.Domain.Tests;

public sealed class BookmarkTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 4, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void CreateKeepsTheUrlAndTrimsTheTitle()
    {
        Bookmark bookmark = Bookmark.Create(new Uri("https://example.com/articles/1"), "  Clean code  ", Now);

        bookmark.Id.Should().NotBe(Guid.Empty);
        bookmark.Url.Should().Be(new Uri("https://example.com/articles/1"));
        bookmark.Title.Should().Be("Clean code");
        bookmark.CreatedAt.Should().Be(Now);
    }

    [Theory]
    [InlineData("ftp://example.com/file")]
    [InlineData("mailto:someone@example.com")]
    public void CreateRejectsAUrlThatIsNotHttpOrHttps(string address)
    {
        Action create = () => Bookmark.Create(new Uri(address), "Title", Now);

        create.Should().Throw<ArgumentException>().WithParameterName("url");
    }

    [Fact]
    public void CreateRejectsARelativeUrl()
    {
        Action create = () => Bookmark.Create(new Uri("/articles/1", UriKind.Relative), "Title", Now);

        create.Should().Throw<ArgumentException>().WithParameterName("url");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void CreateRejectsABlankTitle(string blankTitle)
    {
        Action create = () => Bookmark.Create(new Uri("https://example.com/"), blankTitle, Now);

        create.Should().Throw<ArgumentException>().WithParameterName("title");
    }
}
