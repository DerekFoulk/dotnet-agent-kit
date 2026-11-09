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
    public async Task FindPicksTheRightBookmarkAmongSeveral()
    {
        Bookmark first = Bookmark.Create(new Uri("https://example.com/a"), "A", s_now);
        Bookmark second = Bookmark.Create(new Uri("https://example.com/b"), "B", s_now);
        await SaveAsync(first);
        await SaveAsync(second);

        await using BookmarksDbContext db = new(_options);
        EfBookmarkRepository repository = new(db);

        (await repository.FindAsync(second.Id, TestContext.Current.CancellationToken))!.Title.Should().Be("B");
        (await repository.FindAsync(Guid.NewGuid(), TestContext.Current.CancellationToken)).Should().BeNull();
    }

    [Fact]
    public async Task FindByUrlPicksTheRightBookmarkAmongSeveral()
    {
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/a"), "A", s_now));
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/b"), "B", s_now));

        await using BookmarksDbContext db = new(_options);
        EfBookmarkRepository repository = new(db);

        (await repository.FindByUrlAsync(new Uri("https://example.com/b"), TestContext.Current.CancellationToken))!.Title.Should().Be("B");
        (await repository.FindByUrlAsync(new Uri("https://example.com/c"), TestContext.Current.CancellationToken)).Should().BeNull();
    }

    [Fact]
    public async Task ListReturnsEverySavedBookmark()
    {
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/a"), "A", s_now));
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/b"), "B", s_now.AddMinutes(1)));

        await using BookmarksDbContext db = new(_options);
        IReadOnlyList<Bookmark> all = await new EfBookmarkRepository(db).ListAsync(0, 10, TestContext.Current.CancellationToken);

        all.Select(b => b.Title).Should().BeEquivalentTo("A", "B");
    }

    [Fact]
    public async Task PagesDoNotOverlapAndComeInAStableOrder()
    {
        // API-004: paging happens in the database, in a deterministic order, so no bookmark is skipped or repeated.
        for (int i = 0; i < 3; i++)
        {
            await SaveAsync(Bookmark.Create(new Uri($"https://example.com/{i}"), $"{i}", s_now));
        }

        await using BookmarksDbContext db = new(_options);
        EfBookmarkRepository repository = new(db);
        IReadOnlyList<Bookmark> first = await repository.ListAsync(0, 2, TestContext.Current.CancellationToken);
        IReadOnlyList<Bookmark> second = await repository.ListAsync(2, 2, TestContext.Current.CancellationToken);
        IReadOnlyList<Bookmark> firstAgain = await repository.ListAsync(0, 2, TestContext.Current.CancellationToken);

        first.Should().HaveCount(2);
        second.Should().ContainSingle();
        first.Concat(second).Select(b => b.Id).Should().OnlyHaveUniqueItems();
        firstAgain.Select(b => b.Id).Should().Equal(first.Select(b => b.Id));
    }

    [Fact]
    public async Task PagesComeInCreationOrderWhateverOrderTheRowsWereSavedIn()
    {
        // Review 1 of PR 22: saved in creation order, rows came back in that order even without the OrderBy. Saved
        // out of order, only the key order puts them right.
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/c"), "C", s_now.AddMinutes(2)));
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/a"), "A", s_now));
        await SaveAsync(Bookmark.Create(new Uri("https://example.com/b"), "B", s_now.AddMinutes(1)));

        await using BookmarksDbContext db = new(_options);
        EfBookmarkRepository repository = new(db);
        IReadOnlyList<Bookmark> first = await repository.ListAsync(0, 2, TestContext.Current.CancellationToken);
        IReadOnlyList<Bookmark> second = await repository.ListAsync(2, 2, TestContext.Current.CancellationToken);

        first.Concat(second).Select(b => b.Title).Should().Equal("A", "B", "C");
    }

    [Fact]
    public void TheModelKeysOnIdRequiresEveryFieldCapsTheTitleAndIndexesTheUrl()
    {
        // Mutation testing (PR 23): SQLite doesn't enforce a length, and EF finds "Id" as the key by convention, so
        // no behaviour test noticed when a line of OnModelCreating was removed. These are the schema's promises.
        // EF caches a built model for the whole process; a fresh service provider builds it again, so a mutated
        // OnModelCreating is really run (Stryker reuses one test process across mutants).
        DbContextOptions<BookmarksDbContext> uncached = new DbContextOptionsBuilder<BookmarksDbContext>()
            .UseSqlite(_connection).EnableServiceProviderCaching(false).Options;
        using BookmarksDbContext db = new(uncached);
        Microsoft.EntityFrameworkCore.Metadata.IEntityType bookmark = db.Model.FindEntityType(typeof(Bookmark))!;

        bookmark.FindPrimaryKey()!.Properties.Select(p => p.Name).Should().Equal(nameof(Bookmark.Id));
        bookmark.FindProperty(nameof(Bookmark.Url))!.IsNullable.Should().BeFalse();
        bookmark.FindProperty(nameof(Bookmark.Title))!.IsNullable.Should().BeFalse();
        bookmark.FindProperty(nameof(Bookmark.Title))!.GetMaxLength().Should().Be(500);
        bookmark.FindProperty(nameof(Bookmark.CreatedAt))!.IsNullable.Should().BeFalse();
        bookmark.GetIndexes().Should().ContainSingle(index => index.Properties.Single().Name == nameof(Bookmark.Url));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void InfrastructureNeedsAConnectionString(string blank)
    {
        // Mutation testing (PR 23): without the guard, a blank connection string failed only at the first query.
        Action add = () => Microsoft.Extensions.DependencyInjection.InfrastructureServiceCollectionExtensions
            .AddBookmarksInfrastructure(new Microsoft.Extensions.DependencyInjection.ServiceCollection(), blank);

        add.Should().Throw<ArgumentException>().WithParameterName("connectionString");
    }

    public void Dispose() => _connection.Dispose();

    private async Task SaveAsync(Bookmark bookmark)
    {
        await using BookmarksDbContext db = new(_options);
        await new EfBookmarkRepository(db).AddAsync(bookmark, TestContext.Current.CancellationToken);
    }
}
