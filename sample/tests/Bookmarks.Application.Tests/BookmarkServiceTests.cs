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
    public async Task ListReturnsEveryBookmark()
    {
        Bookmark first = Bookmark.Create(new Uri("https://example.com/a"), "A", s_now);
        Bookmark second = Bookmark.Create(new Uri("https://example.com/b"), "B", s_now);
        _repository.Setup(r => r.ListAsync(It.IsAny<CancellationToken>())).ReturnsAsync([first, second]);

        IReadOnlyList<BookmarkResponse> all = await _service.ListAsync(TestContext.Current.CancellationToken);

        all.Select(b => b.Title).Should().Equal("A", "B");
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
