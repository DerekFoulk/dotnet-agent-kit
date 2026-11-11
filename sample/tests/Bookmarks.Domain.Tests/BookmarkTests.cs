namespace Bookmarks.Domain.Tests;

public sealed class BookmarkTests
{
    private const string Owner = "alice";
    private static readonly DateTimeOffset s_now = new(2026, 11, 4, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void CreateKeepsTheUrlAndTrimsTheTitle()
    {
        Bookmark bookmark = Bookmark.Create(Owner, new Uri("https://example.com/articles/1"), "  Clean code  ", s_now);

        bookmark.Id.Should().NotBe(Guid.Empty);
        bookmark.OwnerId.Should().Be(Owner);
        bookmark.Url.Should().Be(new Uri("https://example.com/articles/1"));
        bookmark.Title.Should().Be("Clean code");
        bookmark.CreatedAt.Should().Be(s_now);
    }

    [Theory]
    [InlineData("ftp://example.com/file")]
    [InlineData("mailto:someone@example.com")]
    public void CreateRejectsAUrlThatIsNotHttpOrHttps(string address)
    {
        Action create = () => Bookmark.Create(Owner, new Uri(address), "Title", s_now);

        create.Should().Throw<ArgumentException>().WithParameterName("url");
    }

    [Fact]
    public void CreateRejectsAMissingUrlByName()
    {
        // Mutation testing (PR 23): without the guard, a null URL failed later with a NullReferenceException.
        Action create = () => Bookmark.Create(Owner, null!, "Title", s_now);

        create.Should().Throw<ArgumentNullException>().WithParameterName("url");
    }

    [Fact]
    public void CreateSaysWhatKindOfUrlItNeeds()
    {
        // Mutation testing (PR 23): the message reaches the API's 400 Problem Details, so it is part of the behaviour.
        Action create = () => Bookmark.Create(Owner, new Uri("ftp://example.com/file"), "Title", s_now);

        create.Should().Throw<ArgumentException>().WithMessage("A bookmark needs an absolute http or https URL.*");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void CreateRejectsAMissingOwner(string? owner)
    {
        // SEC-009: every bookmark belongs to someone, or no query could tell whose it is.
        Action create = () => Bookmark.Create(owner!, new Uri("https://example.com/"), "Title", s_now);

        create.Should().Throw<ArgumentException>().WithParameterName("ownerId");
    }

    [Fact]
    public void CreateKeepsATitleAndAUrlAtTheirLongest()
    {
        // SEC-010: the limits are inclusive. The title is measured after trimming.
        string title = new('t', Bookmark.MaxTitleLength);
        Uri url = new($"https://example.com/{new string('a', Bookmark.MaxUrlLength - "https://example.com/".Length)}");

        Bookmark bookmark = Bookmark.Create(Owner, url, $" {title} ", s_now);

        bookmark.Title.Should().Be(title);
        bookmark.Url.AbsoluteUri.Should().HaveLength(Bookmark.MaxUrlLength);
    }

    [Fact]
    public void CreateRejectsATitleOrAUrlPastItsLimit()
    {
        // SEC-010: a bookmark never holds more than the database column and the API promise.
        Uri tooLong = new($"https://example.com/{new string('a', Bookmark.MaxUrlLength + 1 - "https://example.com/".Length)}");

        Action longTitle = () => Bookmark.Create(Owner, new Uri("https://example.com/"), new string('t', Bookmark.MaxTitleLength + 1), s_now);
        Action longUrl = () => Bookmark.Create(Owner, tooLong, "Title", s_now);

        // The messages reach the API's 400 Problem Details, so they say the limit, never the value.
        longTitle.Should().Throw<ArgumentException>().WithParameterName("title")
            .WithMessage("A bookmark's title has at most 500 characters.*");
        longUrl.Should().Throw<ArgumentException>().WithParameterName("url")
            .WithMessage("A bookmark's URL has at most 2048 characters.*");
    }

    [Fact]
    public void CreateKeepsTheUrlInItsStoredForm()
    {
        // Review 2: the bookmark holds the form it's measured and stored in, so what the API answers on saving is what
        // it answers later, and never longer than the limit.
        Bookmark bookmark = Bookmark.Create(Owner, new Uri("HTTPS://Example.COM:443/a/../b"), "Title", s_now);

        bookmark.Url.OriginalString.Should().Be("https://example.com/b");
    }

    [Fact]
    public void CreateMeasuresTheUrlInItsStoredForm()
    {
        // Review 1: the limit is on the URL as stored, its escaped absolute form. Without a path, that form gains the
        // "/" Uri adds, so a URL written in exactly the limit is one past it.
        Uri noPath = new($"https://example.com?q={new string('a', Bookmark.MaxUrlLength - "https://example.com?q=".Length)}");
        noPath.OriginalString.Should().HaveLength(Bookmark.MaxUrlLength);

        Action create = () => Bookmark.Create(Owner, noPath, "Title", s_now);

        create.Should().Throw<ArgumentException>().WithParameterName("url");
    }

    [Fact]
    public void CreateKeepsAnOwnerIdAtItsLongestAndRejectsOnePast()
    {
        // Review 1: the owner limit lives with the others, so the column and the rule share it (CRF-003).
        string longest = new('o', Bookmark.MaxOwnerIdLength);

        Bookmark bookmark = Bookmark.Create(longest, new Uri("https://example.com/"), "Title", s_now);
        Action tooLong = () => Bookmark.Create(longest + "o", new Uri("https://example.com/"), "Title", s_now);

        bookmark.OwnerId.Should().Be(longest);
        tooLong.Should().Throw<ArgumentException>().WithParameterName("ownerId")
            .WithMessage("A bookmark's owner id has at most 255 characters.*");
    }

    [Fact]
    public void CreateRejectsARelativeUrl()
    {
        Action create = () => Bookmark.Create(Owner, new Uri("/articles/1", UriKind.Relative), "Title", s_now);

        create.Should().Throw<ArgumentException>().WithParameterName("url");
    }

    [Fact]
    public void IdsSortInTheOrderTheBookmarksWereCreated()
    {
        // Review 1 of PR 22: lists are ordered by Id (API-004), so a time-ordered Id (UUID version 7) makes that the
        // creation order, and a new bookmark lands on the last page instead of shifting a random one. Ordinal string
        // order is how the sample's SQLite compares them (SQL Server orders Guids differently: api-design.md).
        List<string> ids = [.. Enumerable.Range(0, 20)
            .Select(minute => Bookmark.Create(Owner, new Uri($"https://example.com/{minute}"), "Title", s_now.AddMinutes(minute)).Id.ToString())];

        ids.Should().BeInAscendingOrder(StringComparer.Ordinal);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void CreateRejectsABlankTitle(string blankTitle)
    {
        Action create = () => Bookmark.Create(Owner, new Uri("https://example.com/"), blankTitle, s_now);

        create.Should().Throw<ArgumentException>().WithParameterName("title");
    }
}
