using System.Reflection;
using ArchUnitNET.Loader;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Bookmarks.Domain;
using Bookmarks.Infrastructure;

namespace Bookmarks.Architecture.Tests;

/// <summary>The sample's production assemblies, loaded once for every architecture test.</summary>
internal static class SampleArchitecture
{
    public static readonly Assembly Domain = typeof(Bookmark).Assembly;
    public static readonly Assembly Contracts = typeof(BookmarkResponse).Assembly;
    public static readonly Assembly Application = typeof(BookmarkService).Assembly;
    public static readonly Assembly Infrastructure = typeof(BookmarksDbContext).Assembly;
    public static readonly Assembly Api = Assembly.Load("Bookmarks.Api");

    public static readonly ArchUnitNET.Domain.Architecture Value =
        new ArchLoader().LoadAssemblies(Domain, Contracts, Application, Infrastructure, Api).Build();
}
