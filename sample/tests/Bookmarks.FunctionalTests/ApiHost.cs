using System.Reflection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.FunctionalTests;

/// <summary>Hosts the API in memory with its own in-memory SQLite database.</summary>
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
            host.UseEnvironment(environment).UseSetting("ConnectionStrings:Bookmarks", connectionString);
            foreach (KeyValuePair<string, string> setting in settings ?? new Dictionary<string, string>())
            {
                host.UseSetting(setting.Key, setting.Value);
            }

            if (services is not null)
            {
                host.ConfigureServices(services);
            }
        });
        Client = _factory.CreateClient();
    }

    public HttpClient Client { get; }

    /// <summary>The running app's services, for tests that check what the app registered.</summary>
    public IServiceProvider Services => _factory.Services;

    public void Dispose()
    {
        Client.Dispose();
        _factory.Dispose();
        _baseFactory.Dispose();
        _keepAlive.Dispose();
    }

    /// <summary>
    /// Sets the API's content root itself, from this assembly's WebApplicationFactoryContentRoot attribute (the .csproj
    /// adds it). The factory's own lookup keys MvcTestingAppManifest.json by the API assembly's full name, which
    /// Stryker.NET's recompiled API doesn't match, so it fell back to a folder that doesn't exist and the API wouldn't
    /// start (ADR-0039). ConfigureWebHost runs after that lookup, so this path wins.
    /// </summary>
    private sealed class ApiFactory : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            string contentRoot = typeof(ApiFactory).Assembly.GetCustomAttributes<WebApplicationFactoryContentRootAttribute>()
                .Single(attribute => attribute.Key == "Bookmarks.Api").ContentRootPath;
            builder.UseContentRoot(contentRoot);
        }
    }
}
