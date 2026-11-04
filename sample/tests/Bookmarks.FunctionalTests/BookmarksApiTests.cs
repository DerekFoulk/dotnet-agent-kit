using System.Net;
using System.Net.Http.Json;
using Bookmarks.Contracts;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;

namespace Bookmarks.FunctionalTests;

/// <summary>The API through its real HTTP pipeline, with an in-memory SQLite database per test.</summary>
public sealed class BookmarksApiTests : IDisposable
{
    private readonly string _connectionString = $"DataSource=bookmarks-{Guid.NewGuid():N};Mode=Memory;Cache=Shared";
    private readonly SqliteConnection _keepAlive;
    private readonly WebApplicationFactory<Program> _baseFactory = new();
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public BookmarksApiTests()
    {
        // An in-memory SQLite database lives as long as one connection to it stays open.
        _keepAlive = new SqliteConnection(_connectionString);
        _keepAlive.Open();
        _factory = _baseFactory.WithWebHostBuilder(host =>
            host.UseSetting("ConnectionStrings:Bookmarks", _connectionString));
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task PostCreatesABookmarkThatGetReturns()
    {
        CreateBookmarkRequest request = new(new Uri("https://example.com/a"), "A");

        using HttpResponseMessage created = await _client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);
        created.StatusCode.Should().Be(HttpStatusCode.Created);
        BookmarkResponse? body = await created.Content.ReadFromJsonAsync<BookmarkResponse>(TestContext.Current.CancellationToken);
        body.Should().NotBeNull();
        created.Headers.Location.Should().Be(new Uri($"/bookmarks/{body!.Id}", UriKind.Relative));

        BookmarkResponse? fetched = await _client.GetFromJsonAsync<BookmarkResponse>(created.Headers.Location, TestContext.Current.CancellationToken);
        fetched.Should().Be(body);

        BookmarkResponse[]? all = await _client.GetFromJsonAsync<BookmarkResponse[]>("/bookmarks", TestContext.Current.CancellationToken);
        all.Should().ContainSingle().Which.Should().Be(body);
    }

    [Fact]
    public async Task PostingASavedUrlAgainIsAConflict()
    {
        CreateBookmarkRequest request = new(new Uri("https://example.com/a"), "A");
        using HttpResponseMessage first = await _client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);

        using HttpResponseMessage second = await _client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);

        second.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    [Fact]
    public async Task PostingAUrlThatIsNotHttpIsABadRequest()
    {
        CreateBookmarkRequest request = new(new Uri("ftp://example.com/file"), "File");

        using HttpResponseMessage response = await _client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GettingAnUnknownBookmarkIsNotFound()
    {
        using HttpResponseMessage response = await _client.GetAsync(new Uri($"/bookmarks/{Guid.NewGuid()}", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
        _baseFactory.Dispose();
        _keepAlive.Dispose();
    }
}
