using Kit.AppTests.Hosting;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The API's WebApplicationFactory. It sets the API's content root itself, the nearest src/Bookmarks.Api above the
/// tests (the kit's ProjectFolder, ADR-0095), because the factory's own lookup can go wrong: it keys
/// MvcTestingAppManifest.json by the API assembly's full name, and MinVer skips the design-time build Stryker.NET
/// compiles from, so Stryker's API has a different version and no match. The factory then falls back to a folder that
/// doesn't exist (ADR-0039). ConfigureWebHost runs after that lookup, so this path wins. It holds in the kit, where the
/// sample is under sample/, and in an app made from the kit, whose projects are at its root.
/// </summary>
internal class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.UseContentRoot(ProjectFolder.Find(AppContext.BaseDirectory, typeof(Program).Assembly.GetName().Name!));
}
