using Bookmarks.Domain;
using Microsoft.EntityFrameworkCore;

namespace Bookmarks.Infrastructure;

/// <summary>The bookmarks database (SQLite).</summary>
public sealed class BookmarksDbContext(DbContextOptions<BookmarksDbContext> options) : DbContext(options)
{
    public DbSet<Bookmark> Bookmarks => Set<Bookmark>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ArgumentNullException.ThrowIfNull(modelBuilder);
        modelBuilder.Entity<Bookmark>(bookmark =>
        {
            bookmark.HasKey(b => b.Id);
            bookmark.Property(b => b.OwnerId).IsRequired().HasMaxLength(Bookmark.MaxOwnerIdLength);
            // Stored in the escaped absolute form whose length the domain limits. EF's default, Uri.ToString(),
            // unescapes some characters, so it can differ from what was measured.
            bookmark.Property(b => b.Url).IsRequired().HasMaxLength(Bookmark.MaxUrlLength)
                .HasConversion(url => url.AbsoluteUri, text => new Uri(text));
            bookmark.Property(b => b.Title).IsRequired().HasMaxLength(Bookmark.MaxTitleLength);
            bookmark.Property(b => b.CreatedAt).IsRequired();
            // Every read filters by owner first (SEC-009), then by URL or by key.
            bookmark.HasIndex(b => new { b.OwnerId, b.Url });
        });
    }
}
