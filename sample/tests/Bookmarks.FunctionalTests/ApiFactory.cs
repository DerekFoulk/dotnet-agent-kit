using System.Reflection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The API's WebApplicationFactory. It sets the API's content root itself, from this assembly's
/// WebApplicationFactoryContentRoot attribute (the .csproj adds it). The factory's own lookup keys
/// MvcTestingAppManifest.json by the API assembly's full name, which Stryker.NET's recompiled API doesn't match, so it
/// fell back to a folder that doesn't exist and the API wouldn't start (ADR-0039). ConfigureWebHost runs after that
/// lookup, so this path wins.
/// </summary>
internal class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        string contentRoot = typeof(ApiFactory).Assembly.GetCustomAttributes<WebApplicationFactoryContentRootAttribute>()
            .Single(attribute => attribute.Key == "Bookmarks.Api").ContentRootPath;
        builder.UseContentRoot(contentRoot);
    }
}
