using System.Net.Http.Headers;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// Hosts the API in memory with its own in-memory SQLite database. Its <see cref="Client"/> signs in as "alice"
/// with a token from <see cref="TestTokens"/>; <see cref="CreateClient"/> makes a client with any other token, or none.
/// </summary>
internal sealed class ApiHost : IDisposable
{
    private readonly SqliteConnection _keepAlive;
    private readonly WebApplicationFactory<Program> _baseFactory = new ApiFactory();
    private readonly WebApplicationFactory<Program> _factory;

    public ApiHost(string environment = "Development", IReadOnlyDictionary<string, string>? settings = null, Action<IServiceCollection>? services = null)
    {
        string connectionString = $"DataSource=bookmarks-{Guid.NewGuid():N};Mode=Memory;Cache=Shared";

        // An in-memory SQLite database lives as long as one connection to it stays open.
        _keepAlive = new SqliteConnection(connectionString);
        _keepAlive.Open();
        _factory = _baseFactory.WithWebHostBuilder(host =>
        {
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

    public void Dispose()
    {
        Client.Dispose();
        _factory.Dispose();
        _baseFactory.Dispose();
        _keepAlive.Dispose();
    }
}
