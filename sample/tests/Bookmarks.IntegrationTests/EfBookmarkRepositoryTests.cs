using Bookmarks.Domain;
using Bookmarks.Infrastructure;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace Bookmarks.IntegrationTests;

/// <summary>The repository against a real SQLite database, held in memory for the test's lifetime.</summary>
public sealed class EfBookmarkRepositoryTests : IDisposable
{
    private static readonly DateTimeOffset s_now = new(2026, 11, 4, 12, 0, 0, TimeSpan.Zero);
    private readonly SqliteConnection _connection = new("DataSource=:memory:");
    private readonly DbContextOptions<BookmarksDbContext> _options;

    public EfBookmarkRepositoryTests()
    {
        _connection.Open();
        _options = new DbContextOptionsBuilder<BookmarksDbContext>().UseSqlite(_connection).Options;
        using BookmarksDbContext db = new(_options);
        db.Database.EnsureCreated();
    }

    [Fact]
    public async Task AddThenFindReturnsTheSameBookmark()
    {
        Bookmark bookmark = Bookmark.Create(new Uri("https://example.com/a"), "A", s_now);
        await SaveAsync(bookmark);

        await using BookmarksDbContext db = new(_options);
        Bookmark? found = await new EfBookmarkRepository(db).FindAsync(bookmark.Id, TestContext.Current.CancellationToken);

        found.Should().NotBeNull();
        found!.Url.Should().Be(bookmark.Url);
        found.Title.Should().Be("A");
        found.CreatedAt.Should().Be(s_now);
    }

    [Fact]
    public async Task FindByUrlFindsTheSavedUrl()
    {
        Bookmark bookmark = Bookmark.Create(new Uri("https://example.com/a"), "A", s_now);
        await SaveAsync(bookmark);

        await using BookmarksDbContext db = new(_options);
        Bookmark? found = await new EfBookmarkRepository(db).FindByUrlAsync(new Uri("https://example.com/a"), TestContext.Current.CancellationToken);

        found.Should().NotBeNull();
        found!.Id.Should().Be(bookmark.Id);
    }

    [Fact]
    public async Task ListReturnsEverySavedBookmark()
    {
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/a"), "A", s_now));
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/b"), "B", s_now.AddMinutes(1)));

        await using BookmarksDbContext db = new(_options);
        IReadOnlyList<Bookmark> all = await new EfBookmarkRepository(db).ListAsync(TestContext.Current.CancellationToken);

        all.Select(b => b.Title).Should().BeEquivalentTo("A", "B");
    }

    public void Dispose() => _connection.Dispose();

    private async Task SaveAsync(Bookmark bookmark)
    {
        await using BookmarksDbContext db = new(_options);
        await new EfBookmarkRepository(db).AddAsync(bookmark, TestContext.Current.CancellationToken);
    }
}
