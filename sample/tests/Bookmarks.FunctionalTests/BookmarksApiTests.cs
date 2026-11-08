using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Bookmarks.Domain;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.FunctionalTests;

/// <summary>The API through its real HTTP pipeline, with an in-memory SQLite database per test.</summary>
public sealed class BookmarksApiTests : IDisposable
{
    private readonly ApiHost _host = new();

    private HttpClient Client => _host.Client;

    [Fact]
    public async Task PostCreatesABookmarkThatGetReturns()
    {
        CreateBookmarkRequest request = new(new Uri("https://example.com/a"), "A");

        using HttpResponseMessage created = await Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);
        created.StatusCode.Should().Be(HttpStatusCode.Created);
        BookmarkResponse? body = await created.Content.ReadFromJsonAsync<BookmarkResponse>(TestContext.Current.CancellationToken);
        body.Should().NotBeNull();
        created.Headers.Location.Should().Be(new Uri($"/bookmarks/{body!.Id}", UriKind.Relative));

        BookmarkResponse? fetched = await Client.GetFromJsonAsync<BookmarkResponse>(created.Headers.Location, TestContext.Current.CancellationToken);
        fetched.Should().Be(body);

        BookmarkResponse[]? all = await Client.GetFromJsonAsync<BookmarkResponse[]>("/bookmarks", TestContext.Current.CancellationToken);
        all.Should().ContainSingle().Which.Should().Be(body);
    }

    [Fact]
    public async Task PostingASavedUrlAgainIsAConflict()
    {
        CreateBookmarkRequest request = new(new Uri("https://example.com/a"), "A");
        using HttpResponseMessage first = await Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);
        first.StatusCode.Should().Be(HttpStatusCode.Created);

        using HttpResponseMessage second = await Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);

        second.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    [Fact]
    public async Task PostingAUrlThatIsNotHttpIsABadRequest()
    {
        CreateBookmarkRequest request = new(new Uri("ftp://example.com/file"), "File");

        using HttpResponseMessage response = await Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GettingAnUnknownBookmarkIsNotFound()
    {
        using HttpResponseMessage response = await Client.GetAsync(new Uri($"/bookmarks/{Guid.NewGuid()}", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task EveryErrorResponseIsProblemDetails()
    {
        // API-002: clients get one error format (RFC 9457), whichever error it is.
        CreateBookmarkRequest request = new(new Uri("https://example.com/a"), "A");
        using HttpResponseMessage created = await Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);
        using HttpResponseMessage conflict = await Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);
        using HttpResponseMessage notFound = await Client.GetAsync(new Uri($"/bookmarks/{Guid.NewGuid()}", UriKind.Relative), TestContext.Current.CancellationToken);
        using HttpResponseMessage noRoute = await Client.GetAsync(new Uri("/no-such-route", UriKind.Relative), TestContext.Current.CancellationToken);

        foreach ((HttpResponseMessage response, HttpStatusCode status) in new[] { (conflict, HttpStatusCode.Conflict), (notFound, HttpStatusCode.NotFound), (noRoute, HttpStatusCode.NotFound) })
        {
            response.StatusCode.Should().Be(status);
            (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json", $"a {(int)status} is Problem Details");
            JsonElement problem = await response.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
            problem.GetProperty("status").GetInt32().Should().Be((int)status);
        }
    }

    [Fact]
    public async Task AnUnhandledErrorIsAProblemWithoutItsDetailsInProduction()
    {
        // API-002: a 500 tells the client something failed, never what or where.
        using ApiHost production = new("Production", services: services => services.AddScoped<IBookmarkRepository>(_ => new BrokenRepository()));

        using HttpResponseMessage response = await production.Client.GetAsync(new Uri($"/bookmarks/{Guid.NewGuid()}", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.InternalServerError);
        (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json");
        string body = await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken);
        body.Should().NotContain(BrokenRepository.Secret).And.NotContain(nameof(BrokenRepository));
    }

    /// <summary>A repository whose every call fails with a message the client must never see.</summary>
    private sealed class BrokenRepository : IBookmarkRepository
    {
        public const string Secret = "connection to db-prod-01 refused";

        public Task<Bookmark?> FindAsync(Guid id, CancellationToken cancellationToken) => throw new InvalidOperationException(Secret);

        public Task<Bookmark?> FindByUrlAsync(Uri url, CancellationToken cancellationToken) => throw new InvalidOperationException(Secret);

        public Task<IReadOnlyList<Bookmark>> ListAsync(CancellationToken cancellationToken) => throw new InvalidOperationException(Secret);

        public Task AddAsync(Bookmark bookmark, CancellationToken cancellationToken) => throw new InvalidOperationException(Secret);
    }

    public void Dispose() => _host.Dispose();
}
