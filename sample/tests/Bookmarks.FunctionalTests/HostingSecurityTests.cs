using System.Net;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// Microsoft's Kestrel production security checklist, as the sample applies it (SEC-011): host filtering, HSTS, rate
/// limiting, no CORS unless an origin is named, a request body cap well under the 30 MB default, and no Server header.
/// </summary>
public sealed class HostingSecurityTests : IDisposable
{
    private readonly ApiHost _host = new("Production");

    public void Dispose() => _host.Dispose();

    [Fact]
    public async Task ARequestForAnotherHostIsRejectedInProduction()
    {
        using HttpRequestMessage request = new(HttpMethod.Get, "/bookmarks");
        request.Headers.Host = "attacker.example";

        using HttpResponseMessage response = await _host.Client.SendAsync(request, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task AnHttpsResponseCarriesHstsInProduction()
    {
        // UseHsts leaves localhost out, so the request names the host a deployment would allow.
        using ApiHost host = new("Production", new Dictionary<string, string> { ["AllowedHosts"] = "bookmarks.example" });
        using HttpRequestMessage request = new(HttpMethod.Get, new Uri("https://bookmarks.example/bookmarks"));

        using HttpResponseMessage response = await host.Client.SendAsync(request, TestContext.Current.CancellationToken);

        response.Headers.Contains("Strict-Transport-Security").Should().BeTrue();
    }

    [Fact]
    public async Task AFloodFromOneCallerIsAnsweredWithTooManyRequests()
    {
        // A burst of 5 and 1 more a second: 20 requests at once go over it, however slow the machine.
        using ApiHost host = new("Production", new Dictionary<string, string>
        {
            ["RateLimiting:BurstLimit"] = "5",
            ["RateLimiting:RequestsPerSecond"] = "1",
        });
        List<HttpStatusCode> statuses = [];
        for (int i = 0; i < 20; i++)
        {
            using HttpResponseMessage response = await host.Client.GetAsync(new Uri("/bookmarks?limit=1", UriKind.Relative), TestContext.Current.CancellationToken);
            statuses.Add(response.StatusCode);
        }

        statuses.Should().Contain(HttpStatusCode.TooManyRequests);
    }

    [Fact]
    public async Task ACrossOriginPreflightGetsNoPermission()
    {
        using HttpRequestMessage preflight = new(HttpMethod.Options, "/bookmarks");
        preflight.Headers.Add("Origin", "https://attacker.example");
        preflight.Headers.Add("Access-Control-Request-Method", "POST");

        using HttpResponseMessage response = await _host.Client.SendAsync(preflight, TestContext.Current.CancellationToken);

        response.Headers.Contains("Access-Control-Allow-Origin").Should().BeFalse();
    }

    [Fact]
    public void KestrelSendsNoServerHeaderAndCapsTheRequestBody()
    {
        KestrelServerOptions kestrel = _host.Services.GetRequiredService<IOptions<KestrelServerOptions>>().Value;

        kestrel.AddServerHeader.Should().BeFalse();
        kestrel.Limits.MaxRequestBodySize.Should().BeLessThanOrEqualTo(1024 * 1024);
    }
}
