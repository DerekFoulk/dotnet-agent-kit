using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The API's WebApplicationFactory. It sets the API's content root itself, relative to the solution file, because the
/// factory's own lookup can go wrong: it keys MvcTestingAppManifest.json by the API assembly's full name, and MinVer
/// skips the design-time build Stryker.NET compiles from, so Stryker's API has a different version and no match. The
/// factory then falls back to a folder that doesn't exist (ADR-0039). ConfigureWebHost runs after that lookup, so this
/// path wins.
/// </summary>
internal class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.UseSolutionRelativeContentRoot(Path.Combine("sample", "src", typeof(Program).Assembly.GetName().Name!));
}
