using System.Net;
using System.Net.Http.Json;
using Bookmarks.Contracts;
using Bookmarks.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.FunctionalTests;

/// <summary>What a signed-in caller may do, and what stays public (SEC-007, ADR-0048).</summary>
public sealed class AuthorizationTests : IDisposable
{
    private readonly ApiHost _host = new();

    [Fact]
    public void OnlyTheHealthEndpointsAndTheOpenApiDocumentAllowAnonymousCallers()
    {
        // SEC-007: every other endpoint falls under the fallback policy. An endpoint added to this list is a
        // decision, made in review, that the whole internet may call it.
        IEnumerable<string?> anonymous = _host.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(endpoint => endpoint.Metadata.GetMetadata<IAllowAnonymous>() is not null)
            .Select(endpoint => endpoint.RoutePattern.RawText);

        anonymous.Should().BeEquivalentTo("/health", "/alive", "/openapi/{documentName}.json");
    }

    [Fact]
    public async Task TheOpenApiDocumentAnswersAnAnonymousCallerInDevelopment()
    {
        // A developer, or a client generator, reads the contract before it has a token. It's served in Development
        // only (API-003).
        using HttpClient anonymous = _host.CreateClient(token: null);

        using HttpResponseMessage response = await anonymous.GetAsync(new Uri("/openapi/v1.json", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task AValidTokenThatNamesNoUserIsForbidden(string? user)
    {
        // SEC-009: the API keeps each user's data apart by the token's sub claim, so a token without one (such as an
        // app's own token, with no user behind it) may not use it. Review 1: a blank sub would be one shared owner.
        using HttpClient noUser = _host.CreateClient(TestTokens.For(user: user));

        using HttpResponseMessage response = await noUser.GetAsync(new Uri("/bookmarks", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json", "a 403 is Problem Details too (API-002)");
    }

    [Fact]
    public async Task ATokenWhoseSubIsTooLongToBeAnOwnerIsForbidden()
    {
        // Review 2: OpenID Connect caps sub at 255 characters, the owner's limit. A longer one is a property of the
        // token, not of the request, so it's a 403 on every endpoint rather than a 400 on saving and a 200 on reading.
        using HttpClient tooLong = _host.CreateClient(TestTokens.For(new string('u', Bookmark.MaxOwnerIdLength + 1)));

        using HttpResponseMessage list = await tooLong.GetAsync(new Uri("/bookmarks", UriKind.Relative), TestContext.Current.CancellationToken);
        using HttpResponseMessage save = await tooLong.PostAsJsonAsync("/bookmarks", new CreateBookmarkRequest(new Uri("https://example.com/a"), "A"), TestContext.Current.CancellationToken);

        list.StatusCode.Should().Be(HttpStatusCode.Forbidden);
        save.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task ATokenWhoseSubIsAtTheLimitGetsThrough()
    {
        // The other edge of the test above: 255 characters is a valid owner id.
        using HttpClient longest = _host.CreateClient(TestTokens.For(new string('u', Bookmark.MaxOwnerIdLength)));

        using HttpResponseMessage save = await longest.PostAsJsonAsync("/bookmarks", new CreateBookmarkRequest(new Uri("https://example.com/a"), "A"), TestContext.Current.CancellationToken);

        save.StatusCode.Should().Be(HttpStatusCode.Created);
    }

    [Fact]
    public async Task AUserSeesOnlyTheirOwnBookmarks()
    {
        // SEC-009 (OWASP API1, broken object-level authorization): another user's bookmark is answered as if it
        // didn't exist, so its id can't even be confirmed, and a URL one user saved is no conflict for another.
        CreateBookmarkRequest request = new(new Uri("https://example.com/a"), "A");
        using HttpResponseMessage saved = await _host.Client.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);
        saved.StatusCode.Should().Be(HttpStatusCode.Created);
        using HttpClient bob = _host.CreateClient(TestTokens.For("bob"));

        using HttpResponseMessage get = await bob.GetAsync(saved.Headers.Location, TestContext.Current.CancellationToken);
        BookmarkPage? list = await bob.GetFromJsonAsync<BookmarkPage>("/bookmarks", TestContext.Current.CancellationToken);
        using HttpResponseMessage sameUrl = await bob.PostAsJsonAsync("/bookmarks", request, TestContext.Current.CancellationToken);

        get.StatusCode.Should().Be(HttpStatusCode.NotFound, "alice's bookmark isn't bob's to see");
        list!.Items.Should().BeEmpty("bob has saved nothing yet");
        sameUrl.StatusCode.Should().Be(HttpStatusCode.Created, "bob's bookmarks are his own, so alice's URL is no conflict");
    }

    public void Dispose() => _host.Dispose();
}
