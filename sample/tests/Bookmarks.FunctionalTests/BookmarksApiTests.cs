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

        BookmarkPage? all = await Client.GetFromJsonAsync<BookmarkPage>("/bookmarks", TestContext.Current.CancellationToken);
        all!.Items.Should().ContainSingle().Which.Should().Be(body);
    }

    [Fact]
    public async Task SavingAndReadingABookmarkAnswerTheSameUrl()
    {
        // Review 2: the 201 echoed the URL as written while GET answered its stored form; both now answer the stored one.
        using StringContent body = new("""{"url":"HTTPS://Example.COM:443/a/../b","title":"A"}""", System.Text.Encoding.UTF8, "application/json");

        using HttpResponseMessage created = await Client.PostAsync(new Uri("/bookmarks", UriKind.Relative), body, TestContext.Current.CancellationToken);
        JsonElement saved = await created.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
        JsonElement fetched = await Client.GetFromJsonAsync<JsonElement>(created.Headers.Location, TestContext.Current.CancellationToken);

        saved.GetProperty("url").GetString().Should().Be("https://example.com/b");
        fetched.GetProperty("url").GetString().Should().Be("https://example.com/b");
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

    [Theory]
    [InlineData("ftp://example.com/file")]
    [InlineData("articles/1")]
    public async Task PostingAUrlThatIsNotHttpIsABadRequest(string address)
    {
        // Review 1: a relative URL has no absolute form for UriLength to measure, so it's measured as written and
        // still reaches the domain's refusal, a 400, never a 500.
        CreateBookmarkRequest request = new(new Uri(address, UriKind.RelativeOrAbsolute), "File");

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
    public async Task TheListComesInPagesLinkedByNextLink()
    {
        // API-004: a list never returns the whole table; each page links to the next until the last.
        for (int i = 0; i < 3; i++)
        {
            using HttpResponseMessage saved = await Client.PostAsJsonAsync("/bookmarks", new CreateBookmarkRequest(new Uri($"https://example.com/{i}"), $"{i}"), TestContext.Current.CancellationToken);
        }

        JsonElement first = await Client.GetFromJsonAsync<JsonElement>("/bookmarks?limit=2", TestContext.Current.CancellationToken);
        first.ValueKind.Should().Be(JsonValueKind.Object, "a page is an object with items and a link to the next page");
        first.GetProperty("items").GetArrayLength().Should().Be(2);
        string next = first.GetProperty("nextLink").GetString()!;
        next.Should().Be("/bookmarks?offset=2&limit=2");

        JsonElement last = await Client.GetFromJsonAsync<JsonElement>(next, TestContext.Current.CancellationToken);
        last.GetProperty("items").GetArrayLength().Should().Be(1);
        last.GetProperty("nextLink").ValueKind.Should().Be(JsonValueKind.Null, "the last page links nowhere");

        JsonElement defaults = await Client.GetFromJsonAsync<JsonElement>("/bookmarks", TestContext.Current.CancellationToken);
        defaults.GetProperty("items").GetArrayLength().Should().Be(3, "with no limit given, a page holds more than 3; the contract snapshot pins the default of 25");
    }

    [Theory]
    [InlineData("limit=0")]
    [InlineData("limit=101")]
    [InlineData("offset=-1")]
    [InlineData("offset=10001")]
    public async Task AnOutOfRangePageIsAValidationProblem(string query)
    {
        // API-004 and API-006: the page size is capped at 100, so no client can ask for the whole table.
        using HttpResponseMessage response = await Client.GetAsync(new Uri($"/bookmarks?{query}", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json");
        JsonElement problem = await response.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
        problem.TryGetProperty("errors", out _).Should().BeTrue("a validation problem names the invalid field");
    }

    public static TheoryData<string, string, string> InvalidBodies() => new()
    {
        { "no title", "title", """{"url":"https://example.com/a"}""" },
        { "a blank title", "title", """{"url":"https://example.com/a","title":"   "}""" },
        { "a title past the limit", "title", $$"""{"url":"https://example.com/a","title":"{{new string('t', Bookmark.MaxTitleLength + 1)}}"}""" },
        { "no URL", "url", """{"title":"A"}""" },
        { "a URL past the limit", "url", $$"""{"url":"{{LongUrl(Bookmark.MaxUrlLength + 1)}}","title":"A"}""" },
        // Review 1: without a path, the stored form gains a "/", so a URL written in exactly the limit is past it.
        // Review 2: a relative URL has no stored form, but it's still bounded where it enters (SEC-010).
        { "a relative URL past the limit", "url", $$"""{"url":"articles/{{new string('a', Bookmark.MaxUrlLength)}}","title":"A"}""" },
        { "a URL with no path, past the limit as stored", "url", $$"""{"url":"https://example.com?q={{new string('a', Bookmark.MaxUrlLength - "https://example.com?q=".Length)}}","title":"A"}""" },
    };

    [Theory]
    [MemberData(nameof(InvalidBodies))]
    public async Task AnInvalidBodyIsAValidationProblemThatNamesTheFieldButNotTheValue(string what, string field, string json)
    {
        // SEC-010 and API-006: the request is checked against the contract before the handler runs. The answer names
        // the field and the rule, never the value, so nothing a client sent is reflected back.
        using StringContent body = new(json, System.Text.Encoding.UTF8, "application/json");

        using HttpResponseMessage response = await Client.PostAsync(new Uri("/bookmarks", UriKind.Relative), body, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest, what);
        (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json");
        string text = await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken);
        using JsonDocument document = JsonDocument.Parse(text);
        JsonElement problem = document.RootElement;
        problem.TryGetProperty("errors", out JsonElement errors).Should().BeTrue($"{what} is a validation problem");
        errors.EnumerateObject().Select(error => error.Name).Should().ContainSingle()
            .Which.Should().BeEquivalentTo(field, options => options.IgnoringCase(), $"{what} is the {field}'s fault");
        text.Should().NotContain("ttttt").And.NotContain("aaaaa", "the answer never repeats what the client sent");
    }

    [Fact]
    public async Task AUrlPastTheLimitIsRefusedWithTheLimitInTheMessage()
    {
        // Mutation testing on PR for GAP-006: an empty UriLength message survived, so this pins what the client reads.
        CreateBookmarkRequest request = new(new Uri(LongUrl(Bookmark.MaxUrlLength + 1)), "A");

        using HttpResponseMessage response = await Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);

        JsonElement problem = await response.Content.ReadFromJsonAsync<JsonElement>(TestContext.Current.CancellationToken);
        string message = problem.GetProperty("errors").EnumerateObject().Single().Value[0].GetString()!;
        message.Should().Contain("at most 2048 characters");
    }

    [Fact]
    public async Task ATitleAndAUrlAtTheirLongestAreSaved()
    {
        // SEC-010: the contract's limits are the domain's (Bookmark.MaxTitleLength and MaxUrlLength), checked here at
        // both edges: one past is refused above, and exactly at the limit is saved.
        CreateBookmarkRequest request = new(new Uri(LongUrl(Bookmark.MaxUrlLength)), new string('t', Bookmark.MaxTitleLength));

        using HttpResponseMessage response = await Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
    }

    private static string LongUrl(int length) => "https://example.com/" + new string('a', length - "https://example.com/".Length);

    [Fact]
    public async Task MalformedInputIsAClientErrorProblemInDevelopmentToo()
    {
        // Review 1 of PR 22: in Development a binding failure throws BadHttpRequestException, and the exception
        // handler turned it into a 500. A client error stays a 400 in every environment.
        using StringContent badJson = new("{ not json", System.Text.Encoding.UTF8, "application/json");
        using HttpResponseMessage body = await Client.PostAsync(new Uri("/bookmarks", UriKind.Relative), badJson, TestContext.Current.CancellationToken);
        using HttpResponseMessage query = await Client.GetAsync(new Uri("/bookmarks?limit=abc", UriKind.Relative), TestContext.Current.CancellationToken);
        using StringContent text = new("https://example.com", System.Text.Encoding.UTF8, "text/plain");
        using HttpResponseMessage mediaType = await Client.PostAsync(new Uri("/bookmarks", UriKind.Relative), text, TestContext.Current.CancellationToken);

        // Review 2 of PR 22: a wrong content type is a 415 Problem too. (It doesn't reach the exception handler: with
        // the handler's selector forced to 400, it is still a 415.)
        foreach ((HttpResponseMessage response, HttpStatusCode status) in new[] { (body, HttpStatusCode.BadRequest), (query, HttpStatusCode.BadRequest), (mediaType, HttpStatusCode.UnsupportedMediaType) })
        {
            response.StatusCode.Should().Be(status, $"{response.RequestMessage!.RequestUri} is the client's error");
            (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json");
        }
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

        public Task<Bookmark?> FindAsync(string ownerId, Guid id, CancellationToken cancellationToken) => throw new InvalidOperationException(Secret);

        public Task<Bookmark?> FindByUrlAsync(string ownerId, Uri url, CancellationToken cancellationToken) => throw new InvalidOperationException(Secret);

        public Task<IReadOnlyList<Bookmark>> ListAsync(string ownerId, int offset, int limit, CancellationToken cancellationToken) => throw new InvalidOperationException(Secret);

        public Task AddAsync(Bookmark bookmark, CancellationToken cancellationToken) => throw new InvalidOperationException(Secret);
    }

    public void Dispose() => _host.Dispose();
}
