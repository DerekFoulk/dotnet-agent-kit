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
            bookmark.Property(b => b.OwnerId).IsRequired();
            bookmark.Property(b => b.Url).IsRequired();
            bookmark.Property(b => b.Title).IsRequired().HasMaxLength(500);
            bookmark.Property(b => b.CreatedAt).IsRequired();
            bookmark.HasIndex(b => b.Url);
        });
    }
}
