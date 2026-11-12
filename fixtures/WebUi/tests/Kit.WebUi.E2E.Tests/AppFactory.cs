using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;

namespace Kit.WebUi.E2E.Tests;

/// <summary>
/// Hosts the fixture app on Kestrel, so a real browser can reach it, on a port the operating system picks: port 0,
/// never Kestrel's default 5000, so two factories (two test classes, two test projects, Stryker's runners) never
/// clash. It sets the app's content root itself, relative to the solution, for the reason the sample's ApiFactory
/// gives: under Stryker.NET the factory's own lookup finds a folder that doesn't exist (ADR-0039).
/// </summary>
internal class AppFactory : WebApplicationFactory<Program>
{
    public AppFactory() => UseKestrel(0);

    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.UseSolutionRelativeContentRoot(Path.Combine("fixtures", "WebUi", "src", typeof(Program).Assembly.GetName().Name!));
}
