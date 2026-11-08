using System.Reflection;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// WebApplicationFactory reads MvcTestingAppManifest.json from the working directory. Stryker.NET runs the tests from
/// the repo root, where it isn't, so the factory fell back to "solution folder + project name", a folder that doesn't
/// exist, and every API test failed on every mutant (PR 23). Its other lookup, a WebApplicationFactoryContentRoot
/// attribute on the test assembly, doesn't depend on the working directory.
/// </summary>
public sealed class ContentRootTests
{
    [Fact]
    public void TheTestsFindTheApiWhateverTheWorkingDirectoryIs()
    {
        WebApplicationFactoryContentRootAttribute api = typeof(ContentRootTests).Assembly
            .GetCustomAttributes<WebApplicationFactoryContentRootAttribute>()
            .Should().ContainSingle(attribute => attribute.Key == "Bookmarks.Api").Subject;

        // The factory accepts the folder only when this marker file is in it.
        File.Exists(Path.Combine(api.ContentRootPath, api.ContentRootTest)).Should().BeTrue();
    }
}
