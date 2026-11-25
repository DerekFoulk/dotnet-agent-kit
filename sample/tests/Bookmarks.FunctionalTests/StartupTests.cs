using System.Net;
using Microsoft.AspNetCore.Hosting;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The app never changes its database's schema when it starts (DAT-004): the deployment applies the migrations, before
/// the new version takes traffic. So it starts, and says it's alive, while its database can't be reached at all.
/// </summary>
public sealed class StartupTests
{

    [Fact]
    public async Task TheAppStartsWithoutTouchingItsDatabase()
    {
        using UnreachableDatabaseFactory factory = new();
        Func<HttpClient> start = factory.CreateClient;

        using HttpClient client = start.Should().NotThrow("the app doesn't reach its database to start").Subject;
        using HttpResponseMessage alive = await client.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        alive.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    /// <summary>The API with <see cref="UnreachableDatabase"/>.</summary>
    private sealed class UnreachableDatabaseFactory : ApiFactory
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseSetting("ConnectionStrings:Bookmarks", UnreachableDatabase);
            base.ConfigureWebHost(builder);
        }
    }
}
