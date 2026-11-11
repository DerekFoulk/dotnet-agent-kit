using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.FunctionalTests;

/// <summary>What a signed-in caller may do, and what stays public (SEC-007, ADR-0046).</summary>
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

    [Fact]
    public async Task AValidTokenThatNamesNoUserIsForbidden()
    {
        // SEC-009: the API keeps each user's data apart by the token's sub claim, so a token without one (such as an
        // app's own token, with no user behind it) may not use it.
        using HttpClient noUser = _host.CreateClient(TestTokens.For(user: null));

        using HttpResponseMessage response = await noUser.GetAsync(new Uri("/bookmarks", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
        (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json", "a 403 is Problem Details too (API-002)");
    }

    public void Dispose() => _host.Dispose();
}
