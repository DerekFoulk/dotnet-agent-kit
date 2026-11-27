using System.Reflection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.AppTests.Functional;

/// <summary>The fixture's one host for the kit's host checks: the site, in memory, through WebApplicationFactory.</summary>
internal static partial class AppHost
{
    public static partial IReadOnlyList<HostUnderTest> Hosts => [new Site()];

    private sealed class Site : HostUnderTest
    {
        public override string Name => "Contoso.Site";

        public override IReadOnlyCollection<string> AnonymousRoutes => [];

        public override string SignedInRoute => "/";

        public override bool ServesHttpApi => false;

        public override IReadOnlyCollection<Assembly> ContractAssemblies => [];

        // The site's endpoints are public. The Pester test sets KIT_FIXTURE_SIGN_IN to run the same build as an app
        // whose endpoints mostly require sign-in.
        public override bool MostEndpointsRequireSignIn => Environment.GetEnvironmentVariable("KIT_FIXTURE_SIGN_IN") == "true";

        public override IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services) =>
            new SiteHost(environment, settings, services);
    }
}

/// <summary>The fixture site, in memory. Nobody signs in, so every client is anonymous.</summary>
internal sealed class SiteHost : IAppUnderTest
{
    private readonly WebApplicationFactory<Program> _baseFactory = new();
    private readonly WebApplicationFactory<Program> _factory;

    public SiteHost(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services)
    {
        _factory = _baseFactory.WithWebHostBuilder(host =>
        {
            host.UseDefaultServiceProvider(options =>
            {
                options.ValidateScopes = true;
                options.ValidateOnBuild = true;
            });
            host.UseEnvironment(environment);
            foreach (KeyValuePair<string, string> setting in settings)
            {
                host.UseSetting(setting.Key, setting.Value);
            }

            host.ConfigureServices(services);
        });
    }

    public IServiceProvider Services => _factory.Services;

    public HttpClient CreateClient(bool signedIn) => _factory.CreateClient();

    public void Dispose()
    {
        _factory.Dispose();
        _baseFactory.Dispose();
    }
}
