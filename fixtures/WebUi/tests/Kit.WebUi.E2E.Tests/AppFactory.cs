using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.WebUi.E2E.Tests;

/// <summary>
/// Hosts the fixture app on Kestrel, so a real browser can reach it, on 127.0.0.1 and a port the operating system
/// picks (LoopbackAddressFilter says how). It sets the app's content root itself, relative to the solution, for the
/// reason the sample's ApiFactory gives: under Stryker.NET the factory's own lookup finds a folder that doesn't exist
/// (ADR-0039).
/// </summary>
internal class AppFactory : WebApplicationFactory<Program>
{
    public AppFactory() => UseKestrel();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);
        builder.UseSolutionRelativeContentRoot(Path.Combine("fixtures", "WebUi", "src", typeof(Program).Assembly.GetName().Name!));
        builder.ConfigureServices(services =>
            services.AddSingleton<IStartupFilter>(provider => new LoopbackAddressFilter(provider.GetRequiredService<IServer>())));
    }
}
