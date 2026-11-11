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
            // The owner is the token's sub claim, which OpenID Connect caps at 255 ASCII characters (Core 1.0, section 2).
            bookmark.Property(b => b.OwnerId).IsRequired().HasMaxLength(255);
            bookmark.Property(b => b.Url).IsRequired().HasMaxLength(Bookmark.MaxUrlLength);
            bookmark.Property(b => b.Title).IsRequired().HasMaxLength(Bookmark.MaxTitleLength);
            bookmark.Property(b => b.CreatedAt).IsRequired();
            // Every read filters by owner first (SEC-009), then by URL or by key.
            bookmark.HasIndex(b => new { b.OwnerId, b.Url });
        });
    }
}
