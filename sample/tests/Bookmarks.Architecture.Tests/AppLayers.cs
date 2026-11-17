using System.Reflection;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Bookmarks.Domain;
using Bookmarks.Infrastructure;

namespace Kit.AppTests.Architecture;

/// <summary>The sample's assemblies, layer by layer, for the kit's architecture tests (tools/AppTests).</summary>
internal static partial class AppLayers
{
    public static partial IReadOnlyList<Assembly> Domain => [typeof(Bookmark).Assembly];

    public static partial IReadOnlyList<Assembly> Contracts => [typeof(BookmarkResponse).Assembly];

    public static partial IReadOnlyList<Assembly> Application => [typeof(BookmarkService).Assembly];

    public static partial IReadOnlyList<Assembly> Infrastructure => [typeof(BookmarksDbContext).Assembly];

    // Program sits in the global namespace, so the API is loaded by name.
    public static partial IReadOnlyList<Assembly> Presentation => [Assembly.Load("Bookmarks.Api")];
}
