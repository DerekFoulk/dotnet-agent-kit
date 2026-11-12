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
    private readonly Uri url = new("https://example.com/articles/benchmarking-dotnet?ref=kit#budgets");
    private readonly DateTimeOffset createdAt = new(2026, 11, 12, 0, 0, 0, TimeSpan.Zero);

    [Benchmark]
    public Bookmark Create() => Bookmark.Create("user-1", url, "  Benchmarking in .NET  ", createdAt);
}
