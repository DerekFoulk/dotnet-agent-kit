using System.Net.Http.Headers;
using Bookmarks.TestDatabase;
using Kit.AppTests.Functional;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Xunit.Sdk;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// Hosts the API in memory with a new database of its own on the tests' SQL Server (DAT-005). Its <see cref="Client"/> signs in as "alice"
/// with a token from <see cref="TestTokens"/>; <see cref="CreateClient"/> makes a client with any other token, or none.
/// </summary>
internal sealed class ApiHost : IAppUnderTest
{
    private readonly WebApplicationFactory<Program> _baseFactory = new ApiFactory();
    private readonly WebApplicationFactory<Program> _factory;

    public ApiHost(string environment = "Development", IReadOnlyDictionary<string, string>? settings = null, Action<IServiceCollection>? services = null)
    {
        // The app needs no database to start (DAT-004). So without Docker it still starts, here, and a test of how it
        // starts sees the real outcome (the kit's DependencyInjectionTests expect the start itself to fail); every
        // other test is skipped once it has (Docker's absence, below).
        string connectionString;
        SkipException? withoutDocker = null;
        try
        {
            connectionString = SqlServerTestDatabase.Create();
        }
        catch (SkipException skip)
        {
            withoutDocker = skip;
            connectionString = ApiFactory.UnreachableDatabase;
        }

        _factory = _baseFactory.WithWebHostBuilder(host =>
        {
            // The container checks the registrations it can when the app starts (not a factory's dependencies, nor open
            // generics), and refuses a scoped service resolved from the root, in whichever environment the test runs, as
            // it does in Development (CRF-013). ASP.NET Core leaves
            // both off in other environments for performance, so the app's own setting stays Microsoft's default; the
            // tests are the gate, and they run the app in Production too.
            host.UseDefaultServiceProvider(options =>
            {
                options.ValidateScopes = true;
                options.ValidateOnBuild = true;
            });
            host.UseEnvironment(environment).UseSetting("ConnectionStrings:Bookmarks", connectionString)
                // The issuer and audience come from configuration, as they do in production (SEC-008).
                .UseSetting("Authentication:Schemes:Bearer:ValidIssuer", TestTokens.Issuer)
                .UseSetting("Authentication:Schemes:Bearer:ValidAudiences:0", TestTokens.Audience);
            foreach (KeyValuePair<string, string> setting in settings ?? new Dictionary<string, string>())
            {
                host.UseSetting(setting.Key, setting.Value);
            }

            // Only the signing key is the test's own: a real app gets its provider's keys from the provider's
            // metadata. Everything else the handler checks is the app's own configuration. The key list is replaced,
            // not added to, so a key dotnet user-jwts left in this machine's user secrets isn't trusted here.
            host.ConfigureServices(collection => collection.PostConfigure<JwtBearerOptions>(
                JwtBearerDefaults.AuthenticationScheme,
                options => options.TokenValidationParameters.IssuerSigningKeys = [TestTokens.SigningKey]));
            if (services is not null)
            {
                host.ConfigureServices(services);
            }
        });
        Client = CreateClient(TestTokens.For());
        if (withoutDocker is not null)
        {
            Dispose();
            throw withoutDocker;
        }
    }

    /// <summary>A client signed in as "alice".</summary>
    public HttpClient Client { get; }

    /// <summary>The running app's services, for tests that check what the app registered.</summary>
    public IServiceProvider Services => _factory.Services;

    /// <summary>A client that sends the given bearer token, or no token when it's null. The caller disposes it.</summary>
    public HttpClient CreateClient(string? token)
    {
        HttpClient client = _factory.CreateClient();
        if (token is not null)
        {
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(JwtBearerDefaults.AuthenticationScheme, token);
        }

        return client;
    }

    /// <summary>A client signed in as "alice", or with no token, for the kit's shared host checks.</summary>
    public HttpClient CreateClient(bool signedIn) => CreateClient(signedIn ? TestTokens.For() : null);

    public void Dispose()
    {
        Client.Dispose();
        _factory.Dispose();
        _baseFactory.Dispose();
    }
}
