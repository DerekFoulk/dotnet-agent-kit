using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Kit.WebUi.E2E.Tests;

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
            .Should().EndWith(Path.Combine("src", "Kit.WebUi"));
    }

    // The app's Program runs on a thread of its own and starts Kestrel itself, while StartServer finishes the factory's
    // setup on the test's thread. Kestrel makes its addresses read-only once it binds, so a factory that changes them
    // after the app has built its host fails whenever Kestrel wins the race, as it did in CI (run 43602912316, and
    // dotnet/aspnetcore#67340). KestrelFirstFactory makes Kestrel win every time.
    [Fact]
    public async Task StartServerSucceedsWhenKestrelBindsBeforeTheFactoryReadsItsAddresses()
    {
        await using KestrelFirstFactory factory = new();

        Action start = factory.StartServer;

        start.Should().NotThrow();
        using HttpClient client = new() { BaseAddress = factory.ClientOptions.BaseAddress };
        using HttpResponseMessage home = await client.GetAsync(new Uri("/", UriKind.Relative), TestContext.Current.CancellationToken);
        home.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    // An app may configure an endpoint of its own on a fixed port, in appsettings.json or code. The factory's address
    // must still be the only one, or two factories would clash on that port, and the browser might be sent to it.
    [Fact]
    public async Task StartServerListensOnlyOnTheSystemPickedPortWhenTheAppConfiguresItsOwnEndpoint()
    {
        await using OwnEndpointFactory factory = new();

        Action start = factory.StartServer;

        start.Should().NotThrow();
        factory.Services.GetRequiredService<IServer>().Features.GetRequiredFeature<IServerAddressesFeature>().Addresses
            .Should().ContainSingle();
        factory.ClientOptions.BaseAddress.Port.Should().NotBe(OwnEndpointFactory.FixedPort);
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

    /// <summary>Gives the app an endpoint of its own on a fixed port, as an appsettings.json Kestrel section would.</summary>
    private sealed class OwnEndpointFactory : AppFactory
    {
        public const int FixedPort = 5000;

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.UseSetting("Kestrel:Endpoints:Own:Url", $"http://127.0.0.1:{FixedPort}");
        }
    }

    /// <summary>
    /// Holds the factory's thread back, whenever it reads the server's features, until Kestrel has bound: the order that
    /// failed in CI. CreateHost runs on the thread that called StartServer, after the factory has registered Kestrel, so
    /// the server it registers here wraps Kestrel's.
    /// </summary>
    private sealed class KestrelFirstFactory : AppFactory
    {
        private const string KestrelKey = "kestrel";

        protected override IHost CreateHost(IHostBuilder builder)
        {
            int factoryThread = Environment.CurrentManagedThreadId;
            builder.ConfigureServices(services =>
            {
                ServiceDescriptor kestrel = services.Last(descriptor => descriptor.ServiceType == typeof(IServer));
                Type kestrelType = kestrel.ImplementationType
                    ?? throw new InvalidOperationException("UseKestrel no longer registers its server by type; wrap it the way it's registered now.");
                services.Remove(kestrel);
                services.Add(new ServiceDescriptor(typeof(IServer), KestrelKey, kestrelType, ServiceLifetime.Singleton));
                services.AddSingleton<IServer>(provider => new BindsFirstServer(provider.GetRequiredKeyedService<IServer>(KestrelKey), factoryThread));
            });
            return base.CreateHost(builder);
        }
    }

    /// <summary>
    /// Kestrel, except that the factory's thread waits for it to bind before it can read its features. The container
    /// owns and disposes Kestrel itself.
    /// </summary>
    private sealed class BindsFirstServer(IServer kestrel, int factoryThread) : IServer
    {
        // A bounded wait, so a server that never starts fails the test instead of hanging it.
        private static readonly TimeSpan s_bindTimeout = TimeSpan.FromSeconds(30);

        private readonly ManualResetEventSlim _bound = new();

        public IFeatureCollection Features
        {
            get
            {
                if (Environment.CurrentManagedThreadId == factoryThread && !_bound.Wait(s_bindTimeout))
                {
                    throw new InvalidOperationException($"Kestrel didn't bind within {s_bindTimeout}, so the order this test needs never happened.");
                }

                return kestrel.Features;
            }
        }

        public async Task StartAsync<TContext>(IHttpApplication<TContext> application, CancellationToken cancellationToken)
            where TContext : notnull
        {
            await kestrel.StartAsync(application, cancellationToken);
            _bound.Set();
        }

        public Task StopAsync(CancellationToken cancellationToken) => kestrel.StopAsync(cancellationToken);

        public void Dispose() => _bound.Dispose();
    }
}
