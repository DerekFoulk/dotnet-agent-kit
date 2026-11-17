using BenchmarkDotNet.Attributes;
using Bookmarks.Domain;

namespace Bookmarks.Benchmarks;

/// <summary>
/// Bookmark.Create runs on every POST /bookmarks: it checks the owner, URL and title and normalizes the URL.
/// BenchmarkDotNet needs the class public and unsealed. Its budget is in benchmark-budget.json.
/// </summary>
[MemoryDiagnoser]
public class BookmarkBenchmarks
{
    private readonly Uri _url = new("https://example.com/articles/benchmarking-dotnet?ref=kit#budgets");
    private readonly DateTimeOffset _createdAt = new(2026, 11, 12, 0, 0, 0, TimeSpan.Zero);

    // The id is made once: Bookmark.Create takes it from its caller (ARC-008), and the API's cost of making one isn't
    // Create's.
    private readonly Guid _id;

    /// <summary>Makes the id each run's bookmark takes.</summary>
    public BookmarkBenchmarks() => _id = Guid.CreateVersion7(_createdAt);

    /// <summary>Makes one bookmark whose title needs trimming.</summary>
    /// <returns>The bookmark, so the work isn't optimized away.</returns>
    [Benchmark]
    public Bookmark Create() => Bookmark.Create(_id, "user-1", _url, "  Benchmarking in .NET  ", _createdAt);
}
