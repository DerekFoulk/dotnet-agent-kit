using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Kit.WebUiFixture.E2E.Tests;

/// <summary>The factory that hosts the app for the browser.</summary>
public sealed class AppFactoryTests
{
    // Port 0 lets the operating system pick a free port each time; Kestrel's default would be 5000 for every factory,
    // and two at once (two test classes, two test projects, Stryker's runners) would clash.
    [Fact]
    public async Task TwoFactoriesRunAtOnceOnPortsTheSystemPicked()
    {
        await using AppFactory first = new();
        await using AppFactory second = new();

        first.StartServer();
        second.StartServer();

        first.ClientOptions.BaseAddress.Port.Should().NotBe(second.ClientOptions.BaseAddress.Port);
        new[] { first, second }.Select(factory => factory.ClientOptions.BaseAddress.Port).Should().NotContain(5000);
    }

    // Under Stryker.NET the factory's own content-root lookup fails (the sample's ContentRootTests says why), so the app
    // must still start, in its own folder, when the content root it's first given is wrong (testing.md).
    [Fact]
    public async Task TheAppStartsInItsOwnFolderWhenTheFactorysLookupGoesWrong()
    {
        await using MisledFactory factory = new();
        factory.StartServer();
        using HttpClient client = new() { BaseAddress = factory.ClientOptions.BaseAddress };

        using HttpResponseMessage home = await client.GetAsync(new Uri("/", UriKind.Relative), TestContext.Current.CancellationToken);

        home.StatusCode.Should().Be(HttpStatusCode.OK);
        factory.Services.GetRequiredService<IHostEnvironment>().ContentRootPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            .Should().EndWith(Path.Combine("src", "Kit.WebUiFixture"));
    }

    /// <summary>Points the content root at a missing folder first, as the factory's fallback does under Stryker.</summary>
    private sealed class MisledFactory : AppFactory
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseContentRoot(Path.Combine(Path.GetTempPath(), "no-such-folder-" + Guid.NewGuid().ToString("N")));
            base.ConfigureWebHost(builder);
        }
    }
}
