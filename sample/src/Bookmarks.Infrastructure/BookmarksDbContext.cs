using Bookmarks.Domain;
using Microsoft.EntityFrameworkCore;

namespace Bookmarks.Infrastructure;

/// <summary>The bookmarks database (SQL Server).</summary>
public sealed class BookmarksDbContext(DbContextOptions<BookmarksDbContext> options) : DbContext(options)
{
    // Compares text exactly, code point by code point, as the app does: SQL Server's default collation ignores case, so
    // "Alice" would read alice's bookmarks (SEC-009) and /A would be a copy of /a.
    private const string Exact = "Latin1_General_100_BIN2";

    /// <summary>Every user's bookmarks; the repository reads only the owner's (SEC-009).</summary>
    public DbSet<Bookmark> Bookmarks => Set<Bookmark>();

    /// <inheritdoc/>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ArgumentNullException.ThrowIfNull(modelBuilder);
        modelBuilder.Entity<Bookmark>(bookmark =>
        {
            // Not clustered: SQL Server sorts a uniqueidentifier by its last six bytes first, a UUID version 7's random
            // part, so a clustered key would put each insert at a random place in the table.
            bookmark.HasKey(b => b.Id).IsClustered(false);
            bookmark.Property(b => b.OwnerId).IsRequired().HasMaxLength(Bookmark.MaxOwnerIdLength).UseCollation(Exact);
            // Stored as the exact text the bookmark holds (its escaped absolute form, whose length the domain limits),
            // and read back unchanged. EF's default, Uri.ToString(), unescapes some characters, and even AbsoluteUri
            // can change on a second pass, so either could differ from what was measured and answered.
            bookmark.Property(b => b.Url).IsRequired().HasMaxLength(Bookmark.MaxUrlLength).UseCollation(Exact)
                .HasConversion(url => url.OriginalString, text => new Uri(text));
            bookmark.Property(b => b.Title).IsRequired().HasMaxLength(Bookmark.MaxTitleLength);
            bookmark.Property(b => b.CreatedAt).IsRequired();
            // The table is clustered by owner, then creation time: every read filters by owner first (SEC-009), a page
            // comes in creation order (API-004), and an owner's new bookmark lands at the end of their rows. A lookup by
            // URL reads the owner's rows. The URL isn't in the key: SQL Server caps an index key at 900 bytes clustered
            // (1,700 otherwise), and the longest owner id and URL take 4,606.
            bookmark.HasIndex(b => new { b.OwnerId, b.CreatedAt }).IsClustered();
        });
    }
}
