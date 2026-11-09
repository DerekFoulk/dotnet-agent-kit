using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The API must start even when WebApplicationFactory's own content-root lookup goes wrong. Under Stryker.NET it does:
/// MinVer skips the design-time build Stryker compiles from, so the recompiled API's version (1.0.0.0) doesn't match
/// the key in MvcTestingAppManifest.json (0.0.0.0), and the factory falls back to a folder that doesn't exist. Every
/// API test then failed on every mutant (PR 23, ADR-0039).
/// </summary>
public sealed class ContentRootTests
{
    [Fact]
    public async Task TheApiStartsInItsOwnFolderWhenTheFactorysLookupGoesWrong()
    {
        using MisledFactory factory = new();
        using HttpClient client = factory.CreateClient();

        using HttpResponseMessage alive = await client.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        alive.StatusCode.Should().Be(HttpStatusCode.OK);
        factory.Services.GetRequiredService<IHostEnvironment>().ContentRootPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            .Should().EndWith(Path.Combine("src", "Bookmarks.Api"));
    }

    /// <summary>Points the content root at a missing folder first, as the factory's fallback does under Stryker.</summary>
    private sealed class MisledFactory : ApiFactory
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseContentRoot(Path.Combine(Path.GetTempPath(), "no-such-folder-" + Guid.NewGuid().ToString("N")))
                .UseSetting("ConnectionStrings:Bookmarks", "DataSource=:memory:");
            base.ConfigureWebHost(builder);
        }
    }
}
