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
    /// <summary>
    /// A database nothing answers for: nothing listens on port 1, and the client waits a second. The app starts with it,
    /// since it never touches its database to start (DAT-004).
    /// </summary>
    public const string UnreachableDatabase = "Server=127.0.0.1,1;Database=Bookmarks;Connect Timeout=1;Encrypt=False";

    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.UseSolutionRelativeContentRoot(Path.Combine("sample", "src", typeof(Program).Assembly.GetName().Name!));
}
