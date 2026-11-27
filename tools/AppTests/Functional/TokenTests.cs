using System.Buffers.Text;
using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace Kit.AppTests.Functional;

/// <summary>
/// An HTTP API accepts only valid access tokens (SEC-008): a caller with no token, an unsigned one, one whose claims
/// changed after it was signed, or one signed with a key the host doesn't trust is a 401 Problem that names the Bearer
/// scheme. Each is made from the host's own signed-in token, so none needs the app's key, issuer or audience; a token
/// that's expired, or from another issuer or for another API, needs the app's key to sign, so the app's own tests check
/// those, as the sample's do. A host that signs nobody in, such as a public website, has no token to check, so they skip,
/// and none of its endpoints may require authorization.
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
        Assert.SkipUnless(described.SignsUsersIn, AppHost.NoSignIn);
        using IAppUnderTest app = described.Start(Environments.Production);
        using HttpClient client = app.CreateClient(signedIn: true);
        BearerToken(client);

        using HttpResponseMessage response = await client.GetAsync(new Uri(described.Route, UriKind.Relative), TestContext.Current.CancellationToken);

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
        Assert.SkipUnless(described.SignsUsersIn, AppHost.NoSignIn);
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

        using HttpResponseMessage response = await client.GetAsync(new Uri(described.Route, UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized, $"{caller} is no signed-in user");
        response.Headers.WwwAuthenticate.Should().Contain(header => header.Scheme == "Bearer", "a 401 tells the client which scheme to use");
        (response.Content.Headers.ContentType?.MediaType).Should().Be("application/problem+json", "a 401 is Problem Details too (API-002)");
    }

    // Saying the host signs nobody in skips the checks above, so the statement is checked against the host, started as
    // they start it: none of its endpoints may require authorization, which only a signed-in user could pass, it can't
    // also say that most do, and it has no authentication scheme. Without one, nobody could pass a fallback policy or
    // MVC's global filter either, and neither shows in an endpoint's metadata.
    [Theory]
    [EachHost]
    public void AHostThatSignsNobodyInHasNoAuthenticationOrProtectedEndpoint(string host)
    {
        HostUnderTest described = AppHost.Named(host);
        Assert.SkipWhen(described.SignsUsersIn, AppHost.UsersSignIn);
        using IAppUnderTest app = described.Start(Environments.Production);

        described.MostEndpointsRequireSignIn.Should().BeFalse("most endpoints can't require sign-in in a host that signs nobody in");
        IEnumerable<string> authorized = EndpointAuthorization.Protected(app.Services)
            .Select(endpoint => $"{string.Join(',', endpoint.Metadata.GetMetadata<IHttpMethodMetadata>()?.HttpMethods ?? ["*"])} {endpoint.RoutePattern.RawText}");

        authorized.Should().BeEmpty("only a signed-in user passes an endpoint's authorization, so a host with one signs users in (HostUnderTest.SignsUsersIn)");
        app.Services.GetRequiredService<IOptions<AuthenticationOptions>>().Value.Schemes.Select(scheme => scheme.Name)
            .Should().BeEmpty("an authentication scheme signs users in (HostUnderTest.SignsUsersIn)");
    }

    // An HTTP API that signs users in takes JWT bearer tokens (SEC-008), so its signed-in client sends one: header,
    // payload and signature.
    private static string BearerToken(HttpClient signedIn)
    {
        AuthenticationHeaderValue? authorization = signedIn.DefaultRequestHeaders.Authorization;
        authorization?.Scheme.Should().Be("Bearer");
        string? token = authorization?.Parameter;
        token.Should().NotBeNull("a host that serves an HTTP API and signs users in takes JWT bearer tokens (SEC-008), so CreateClient(signedIn: true) sends one in its Authorization header");
        token!.Split('.').Should().HaveCount(3, "a signed JWT is a header, a payload and a signature");
        return token;
    }

    private static string? Changed(string caller, string token)
    {
        string[] parts = token.Split('.');
        return caller switch
        {
            NoToken => null,
            Unsigned => $"{Encoded(new JsonObject { ["alg"] = "none", ["typ"] = "JWT" })}.{parts[1]}.",
            ClaimsChanged => $"{parts[0]}.{Encoded(WithClaim(parts[1]))}.{parts[2]}",
            OtherKey => SignedWithANewKey(parts[1]),
            _ => throw new ArgumentOutOfRangeException(nameof(caller), caller, "No such change."),
        };
    }

    // The same claims, and one more, so the signature no longer matches them.
    private static JsonObject WithClaim(string payload)
    {
        JsonObject claims = JsonNode.Parse(Base64Url.DecodeFromChars(payload))!.AsObject();
        claims["kit_changed"] = true;
        return claims;
    }

    // A well-formed RS256 token whose key the host has never seen: made here, with an id of its own, and dropped.
    private static string SignedWithANewKey(string payload)
    {
        using RSA key = RSA.Create(2048);
        string signed = $"{Encoded(new JsonObject { ["alg"] = "RS256", ["typ"] = "JWT", ["kid"] = Guid.NewGuid().ToString("N") })}.{payload}";
        byte[] signature = key.SignData(Encoding.ASCII.GetBytes(signed), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return $"{signed}.{Base64Url.EncodeToString(signature)}";
    }

    private static string Encoded(JsonObject json) => Base64Url.EncodeToString(Encoding.UTF8.GetBytes(json.ToJsonString()));
}
