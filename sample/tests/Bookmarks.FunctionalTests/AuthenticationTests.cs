using System.Net;

namespace Bookmarks.FunctionalTests;

/// <summary>Who may call the API: only a caller with a valid access token (SEC-007, SEC-008, ADR-0046).</summary>
public sealed class AuthenticationTests : IDisposable
{
    private readonly ApiHost _host = new();

    public static TheoryData<string, string?> RejectedTokens() => new()
    {
        { "no token", null },
        { "an expired token", TestTokens.For(expiresIn: TimeSpan.FromHours(-1)) },
        { "a token from another issuer", TestTokens.For(issuer: "https://login.other.test/") },
        { "a token for another API", TestTokens.For(audience: "api://another-api") },
        { "a token signed with a key the API doesn't trust", TestTokens.For(key: TestTokens.NewKey()) },
        { "an unsigned token", TestTokens.For(signed: false) },
    };

    [Theory]
    [MemberData(nameof(RejectedTokens))]
    public async Task EveryBookmarksEndpointAnswersACallerWithoutAValidTokenWith401(string caller, string? token)
    {
        using HttpClient client = _host.CreateClient(token);
        using HttpResponseMessage list = await client.GetAsync(new Uri("/bookmarks", UriKind.Relative), TestContext.Current.CancellationToken);
        using HttpResponseMessage get = await client.GetAsync(new Uri($"/bookmarks/{Guid.NewGuid()}", UriKind.Relative), TestContext.Current.CancellationToken);
        using StringContent body = new("""{"url":"https://example.com/a","title":"A"}""", System.Text.Encoding.UTF8, "application/json");
        using HttpResponseMessage create = await client.PostAsync(new Uri("/bookmarks", UriKind.Relative), body, TestContext.Current.CancellationToken);

        foreach (HttpResponseMessage response in new[] { list, get, create })
        {
            response.StatusCode.Should().Be(HttpStatusCode.Unauthorized, $"{caller} is no signed-in user ({response.RequestMessage!.Method} {response.RequestMessage.RequestUri})");
            response.Headers.WwwAuthenticate.Should().Contain(header => header.Scheme == "Bearer", "a 401 tells the client which scheme to use");
            (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json", "a 401 is Problem Details too (API-002)");
        }
    }

    [Fact]
    public async Task AValidTokenGetsThrough()
    {
        using HttpResponseMessage response = await _host.Client.GetAsync(new Uri("/bookmarks", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    public void Dispose() => _host.Dispose();
}
