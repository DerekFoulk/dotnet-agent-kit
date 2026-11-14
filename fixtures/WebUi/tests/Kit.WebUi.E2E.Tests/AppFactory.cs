using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;

namespace Kit.WebUi.E2E.Tests;

/// <summary>
/// Hosts the fixture app on Kestrel, so a real browser can reach it, on 127.0.0.1 and a port the operating system
/// picks: port 0, never Kestrel's default 5000, so two factories (two test classes, two test projects, Stryker's
/// runners) never clash. It sets the app's content root itself, relative to the solution, for the reason the sample's
/// ApiFactory gives: under Stryker.NET the factory's own lookup finds a folder that doesn't exist (ADR-0039).
/// </summary>
/// <remarks>
/// The endpoint goes in Kestrel's options, which Kestrel reads before it binds. UseKestrel(0) would instead rewrite the
/// server's addresses after the app has built its host, while the app's Program starts Kestrel on a thread of its own,
/// and that throws whenever Kestrel binds first (dotnet/aspnetcore#67340; fixed after .NET 10 by #67714, which moves
/// UseKestrel(port) to this same Listen call).
/// </remarks>
internal class AppFactory : WebApplicationFactory<Program>
{
    public AppFactory() => UseKestrel(options => options.Listen(IPAddress.Loopback, 0));

    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.UseSolutionRelativeContentRoot(Path.Combine("fixtures", "WebUi", "src", typeof(Program).Assembly.GetName().Name!));
}
