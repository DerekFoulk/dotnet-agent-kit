using System.Reflection;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Bookmarks.Domain;

namespace Bookmarks.Architecture.Tests;

/// <summary>ARC-003: shared libraries reference no UI, web or platform package, so any front end can use them.</summary>
public sealed class SharedLibraryTests
{
    private static readonly string[] s_forbiddenPrefixes =
    [
        "Microsoft.AspNetCore",
        "Microsoft.EntityFrameworkCore",
        "Microsoft.Maui",
        "PresentationFramework",
        "System.Windows",
    ];

    public static TheoryData<string> SharedLibraries => new()
    {
        typeof(Bookmark).Assembly.GetName().Name!,
        typeof(BookmarkResponse).Assembly.GetName().Name!,
        typeof(BookmarkService).Assembly.GetName().Name!,
    };

    [Theory]
    [MemberData(nameof(SharedLibraries))]
    public void ReferencesNoUiOrPlatformPackage(string libraryName)
    {
        IEnumerable<string> references = Assembly.Load(libraryName).GetReferencedAssemblies().Select(reference => reference.Name!);

        references.Should().NotContain(name => s_forbiddenPrefixes.Any(prefix => name.StartsWith(prefix, StringComparison.Ordinal)));
    }
}
