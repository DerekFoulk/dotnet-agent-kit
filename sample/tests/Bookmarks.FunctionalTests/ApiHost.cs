using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;

namespace Bookmarks.FunctionalTests;

/// <summary>Hosts the API in memory with its own in-memory SQLite database.</summary>
internal sealed class ApiHost : IDisposable
{
    private readonly SqliteConnection _keepAlive;
    private readonly WebApplicationFactory<Program> _baseFactory = new();
    private readonly WebApplicationFactory<Program> _factory;

    public ApiHost(string environment = "Development", IReadOnlyDictionary<string, string>? settings = null)
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
}
