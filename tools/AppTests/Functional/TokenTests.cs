using System.Net;
using System.Net.Http.Headers;
using Microsoft.Extensions.Hosting;

namespace Kit.AppTests.Functional;

/// <summary>
/// An HTTP API accepts only valid access tokens (SEC-008): a caller with no token, an unsigned one, one whose claims
/// changed after it was signed, or one signed with a key the host doesn't trust is a 401 Problem that names the Bearer
/// scheme. Each is made from the host's own signed-in token, so none needs the app's key, issuer or audience; a token
/// that's expired, or from another issuer or for another API, needs the app's key to sign, so the app's own tests check
/// those, as the sample's do.
/// </summary>
public sealed class TokenTests
{
    private const string NoToken = "no token";
    private const string Unsigned = "an unsigned token";
    private const string ClaimsChanged = "a token whose claims changed after it was signed";
    private const string OtherKey = "a token signed with a key the host doesn't trust";

    // The control: the token every other case is made from gets through, so each 401 comes from the change.
    [Theory]
    [EachHost]
    public async Task TheSignedInClientsBearerTokenGetsThrough(string host)
    {
        HostUnderTest described = AppHost.Named(host);
        Assert.SkipUnless(described.ServesHttpApi, AppHost.NoHttpApi);
        using IAppUnderTest app = described.Start(Environments.Production);
        using HttpClient client = app.CreateClient(signedIn: true);
        BearerToken(client);

        using HttpResponseMessage response = await client.GetAsync(new Uri(described.SignedInRoute, UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().NotBe(HttpStatusCode.Unauthorized, "the signed-in client's token is valid");
    }

    [Theory]
    [EachHost(NoToken)]
    [EachHost(Unsigned)]
    [EachHost(ClaimsChanged)]
    [EachHost(OtherKey)]
    public async Task ACallerWithoutAValidTokenIsA401Problem(string host, string caller)
    {
        HostUnderTest described = AppHost.Named(host);
        Assert.SkipUnless(described.ServesHttpApi, AppHost.NoHttpApi);
        using IAppUnderTest app = described.Start(Environments.Production);
        string token;
        using (HttpClient signedIn = app.CreateClient(signedIn: true))
        {
            token = BearerToken(signedIn);
        }

        using HttpClient client = app.CreateClient(signedIn: false);
        if (Changed(caller, token) is { } sent)
        {
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", sent);
        }

        using HttpResponseMessage response = await client.GetAsync(new Uri(described.SignedInRoute, UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized, $"{caller} is no signed-in user");
        response.Headers.WwwAuthenticate.Should().Contain(header => header.Scheme == "Bearer", "a 401 tells the client which scheme to use");
        (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json", "a 401 is Problem Details too (API-002)");
    }

    // An HTTP API takes JWT bearer tokens (SEC-008), so its signed-in client sends one: header, payload and signature.
    private static string BearerToken(HttpClient signedIn)
    {
        AuthenticationHeaderValue? authorization = signedIn.DefaultRequestHeaders.Authorization;
        authorization?.Scheme.Should().Be("Bearer");
        string? token = authorization?.Parameter;
        token.Should().NotBeNull("a host that serves an HTTP API takes JWT bearer tokens (SEC-008), so CreateClient(signedIn: true) sends one in its Authorization header");
        token!.Split('.').Should().HaveCount(3, "a signed JWT is a header, a payload and a signature");
        return token;
    }

    private static string? Changed(string caller, string token) => caller switch
    {
        NoToken => null,
        _ => token,
    };
}
