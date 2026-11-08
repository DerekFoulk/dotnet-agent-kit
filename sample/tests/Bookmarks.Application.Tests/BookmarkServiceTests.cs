using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Bookmarks.Domain;
using Moq;

namespace Bookmarks.Application.Tests;

public sealed class BookmarkServiceTests
{
    private static readonly DateTimeOffset s_now = new(2026, 11, 4, 12, 0, 0, TimeSpan.Zero);
    private readonly Mock<IBookmarkRepository> _repository = new();
    private readonly BookmarkService _service;

    public BookmarkServiceTests()
    {
        _service = new BookmarkService(_repository.Object, new FixedTimeProvider(s_now));
    }

    [Fact]
    public async Task AddSavesANewBookmarkAndReturnsIt()
    {
        CreateBookmarkRequest request = new(new Uri("https://example.com/a"), "A");

        AddBookmarkResult result = await _service.AddAsync(request, TestContext.Current.CancellationToken);

        result.AlreadyExists.Should().BeFalse();
        result.Bookmark.Should().NotBeNull();
        result.Bookmark!.Url.Should().Be(request.Url);
        result.Bookmark.Title.Should().Be("A");
        result.Bookmark.CreatedAt.Should().Be(s_now);
        _repository.Verify(r => r.AddAsync(It.Is<Bookmark>(b => b.Url == request.Url), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task AddRefusesAUrlThatIsAlreadySaved()
    {
        Bookmark existing = Bookmark.Create(new Uri("https://example.com/a"), "A", s_now);
        _repository.Setup(r => r.FindByUrlAsync(existing.Url, It.IsAny<CancellationToken>())).ReturnsAsync(existing);

        AddBookmarkResult result = await _service.AddAsync(new CreateBookmarkRequest(existing.Url, "Again"), TestContext.Current.CancellationToken);

        result.AlreadyExists.Should().BeTrue();
        result.Bookmark.Should().BeNull();
        _repository.Verify(r => r.AddAsync(It.IsAny<Bookmark>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task GetReturnsTheBookmarkOrNothing()
    {
        Bookmark saved = Bookmark.Create(new Uri("https://example.com/a"), "A", s_now);
        _repository.Setup(r => r.FindAsync(saved.Id, It.IsAny<CancellationToken>())).ReturnsAsync(saved);

        BookmarkResponse? found = await _service.GetAsync(saved.Id, TestContext.Current.CancellationToken);
        BookmarkResponse? missing = await _service.GetAsync(Guid.NewGuid(), TestContext.Current.CancellationToken);

        found.Should().Be(new BookmarkResponse(saved.Id, saved.Url, "A", s_now));
        missing.Should().BeNull();
    }

    [Fact]
    public async Task ListReturnsAPageAndSaysWhetherAnotherFollows()
    {
        // API-004: one extra row tells the service another page exists, without counting the whole table.
        Bookmark a = Bookmark.Create(new Uri("https://example.com/a"), "A", s_now);
        Bookmark b = Bookmark.Create(new Uri("https://example.com/b"), "B", s_now);
        Bookmark c = Bookmark.Create(new Uri("https://example.com/c"), "C", s_now);
        _repository.Setup(r => r.ListAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<CancellationToken>())).ReturnsAsync([]);
        _repository.Setup(r => r.ListAsync(0, 3, It.IsAny<CancellationToken>())).ReturnsAsync([a, b, c]);
        _repository.Setup(r => r.ListAsync(2, 3, It.IsAny<CancellationToken>())).ReturnsAsync([c]);

        BookmarkListResult first = await _service.ListAsync(0, 2, TestContext.Current.CancellationToken);
        BookmarkListResult last = await _service.ListAsync(2, 2, TestContext.Current.CancellationToken);

        first.Items.Select(bookmark => bookmark.Title).Should().Equal("A", "B");
        first.HasMore.Should().BeTrue();
        last.Items.Select(bookmark => bookmark.Title).Should().Equal("C");
        last.HasMore.Should().BeFalse();
    }

    [Fact]
    public async Task AFullLastPageSaysNoneFollows()
    {
        // Review 1 of PR 22: a last page holding exactly `limit` bookmarks must not link to an empty page.
        Bookmark a = Bookmark.Create(new Uri("https://example.com/a"), "A", s_now);
        Bookmark b = Bookmark.Create(new Uri("https://example.com/b"), "B", s_now);
        _repository.Setup(r => r.ListAsync(0, 3, It.IsAny<CancellationToken>())).ReturnsAsync([a, b]);

        BookmarkListResult page = await _service.ListAsync(0, 2, TestContext.Current.CancellationToken);

        page.Items.Should().HaveCount(2);
        page.HasMore.Should().BeFalse();
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(0, 101)]
    [InlineData(0, int.MaxValue)]
    [InlineData(-1, 25)]
    [InlineData(10_001, 25)]
    public async Task AnOutOfRangePageIsRefusedEvenWithoutTheEndpoint(int offset, int limit)
    {
        // Review 1 of PR 22: only the endpoint's [Range] guarded the page, and int.MaxValue + 1 overflows into a
        // negative LIMIT, which SQLite reads as no limit at all.
        _repository.Setup(r => r.ListAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<CancellationToken>())).ReturnsAsync([]);

        Func<Task> list = () => _service.ListAsync(offset, limit, TestContext.Current.CancellationToken);

        await list.Should().ThrowAsync<ArgumentOutOfRangeException>();
    }

    [Theory]
    [InlineData(0, 1)]
    [InlineData(0, BookmarkService.MaxPageSize)]
    [InlineData(BookmarkService.MaxOffset, 1)]
    public async Task APageAtTheLimitsIsAccepted(int offset, int limit)
    {
        // Review 2 of PR 22: the endpoint's [Range] allows these, so the service must too, or a valid request is a 500.
        _repository.Setup(r => r.ListAsync(It.IsAny<int>(), It.IsAny<int>(), It.IsAny<CancellationToken>())).ReturnsAsync([]);

        Func<Task> list = () => _service.ListAsync(offset, limit, TestContext.Current.CancellationToken);

        await list.Should().NotThrowAsync();
    }

    [Fact]
    public async Task NoPageFollowsPastTheDeepestOffset()
    {
        // Review 3 of PR 22: a next page starting past MaxOffset would be refused, so the page before it is the last.
        Bookmark[] rows = [.. Enumerable.Range(0, 101).Select(i => Bookmark.Create(new Uri($"https://example.com/{i}"), $"{i}", s_now))];
        _repository.Setup(r => r.ListAsync(9_950, 101, It.IsAny<CancellationToken>())).ReturnsAsync(rows);

        BookmarkListResult page = await _service.ListAsync(9_950, 100, TestContext.Current.CancellationToken);

        page.Items.Should().HaveCount(100);
        page.HasMore.Should().BeFalse("a page from offset 10,050 is past the deepest offset the API accepts");
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
