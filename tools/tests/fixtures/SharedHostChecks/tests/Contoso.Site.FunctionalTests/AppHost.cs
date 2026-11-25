using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.AppTests.Functional;

/// <summary>How the kit's host checks start the fixture site: in memory, through WebApplicationFactory.</summary>
internal static partial class AppHost
{
    public static partial IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services) =>
        new SiteHost(environment, settings, services);

    public static partial IReadOnlyCollection<string> AnonymousRoutes => [];

    public static partial string SignedInRoute => "/";

    public static partial bool ServesHttpApi => false;

    // The site's endpoints are public. The Pester test sets KIT_FIXTURE_SIGN_IN to run the same build as an app whose
    // endpoints mostly require sign-in.
    public static partial bool MostEndpointsRequireSignIn => Environment.GetEnvironmentVariable("KIT_FIXTURE_SIGN_IN") == "true";
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
