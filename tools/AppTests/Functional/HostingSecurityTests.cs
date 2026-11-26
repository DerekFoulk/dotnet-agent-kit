using System.Net;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace Kit.AppTests.Functional;

/// <summary>
/// Microsoft's Kestrel production security checklist, the parts every app applies the same way (SEC-011): host
/// filtering, HSTS, no CORS unless an origin is named, a request body cap well under the 30 MB default, and no Server
/// header. The rate limit's settings are the app's own, so its own tests check it.
/// </summary>
public sealed class HostingSecurityTests
{
    private const string AllowedHost = "kit-app.example";
    private const string OtherHost = "attacker.example";

    [Theory]
    [EachHost]
    public async Task ARequestForAnotherHostIsRejectedInProduction(string host)
    {
        using IAppUnderTest app = AppHost.Named(host).Start(Environments.Production);
        using HttpClient client = app.CreateClient(signedIn: true);
        using HttpRequestMessage request = new(HttpMethod.Get, AppHost.Named(host).SignedInRoute);
        request.Headers.Host = OtherHost;

        using HttpResponseMessage response = await client.SendAsync(request, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    // UseHsts leaves localhost out, so the request names a host a deployment would allow.
    [Theory]
    [EachHost]
    public async Task AnHttpsResponseCarriesHstsInProduction(string host)
    {
        using IAppUnderTest app = AppHost.Named(host).Start(Environments.Production, new Dictionary<string, string> { ["AllowedHosts"] = AllowedHost });
        using HttpClient client = app.CreateClient(signedIn: true);
        using HttpRequestMessage request = new(HttpMethod.Get, new Uri($"https://{AllowedHost}{AppHost.Named(host).SignedInRoute}"));

        using HttpResponseMessage response = await client.SendAsync(request, TestContext.Current.CancellationToken);

        response.Headers.Contains("Strict-Transport-Security").Should().BeTrue();
    }

    [Theory]
    [EachHost]
    public async Task ACrossOriginPreflightGetsNoPermission(string host)
    {
        using IAppUnderTest app = AppHost.Named(host).Start(Environments.Production);
        using HttpClient client = app.CreateClient(signedIn: true);
        using HttpRequestMessage preflight = new(HttpMethod.Options, AppHost.Named(host).SignedInRoute);
        preflight.Headers.Add("Origin", $"https://{OtherHost}");
        preflight.Headers.Add("Access-Control-Request-Method", "POST");

        using HttpResponseMessage response = await client.SendAsync(preflight, TestContext.Current.CancellationToken);

        response.Headers.Contains("Access-Control-Allow-Origin").Should().BeFalse();
    }

    [Theory]
    [EachHost]
    public void KestrelSendsNoServerHeaderAndCapsTheRequestBody(string host)
    {
        using IAppUnderTest app = AppHost.Named(host).Start(Environments.Production);

        KestrelServerOptions kestrel = app.Services.GetRequiredService<IOptions<KestrelServerOptions>>().Value;

        kestrel.AddServerHeader.Should().BeFalse();
        kestrel.Limits.MaxRequestBodySize.Should().BeLessThanOrEqualTo(1024 * 1024);
    }
}
