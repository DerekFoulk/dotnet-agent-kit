using System.Diagnostics;
using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Timeouts;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace Kit.AppTests.Functional;

/// <summary>
/// The health endpoints every ASP.NET Core app maps (OPS-002): /health for readiness and /alive for liveness, in every
/// environment, answering an anonymous probe (SEC-007) with the status word only, cached briefly and time-boxed.
/// </summary>
public sealed class HealthTests
{
    private const string Healthy = "Healthy";
    private const string Health = "/health";
    private const string Alive = "/alive";
    private static readonly Uri s_health = new(Health, UriKind.Relative);
    private static readonly Uri s_alive = new(Alive, UriKind.Relative);

    // Probes call without a token, and need the endpoints in production; details would tell an attacker what the app
    // depends on.
    [Theory]
    [InlineData(Alive)]
    [InlineData(Health)]
    public async Task AHealthEndpointAnswersAnAnonymousProbeWithTheStatusOnlyInProduction(string path)
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production);
        using HttpClient probe = app.CreateClient(signedIn: false);

        using HttpResponseMessage response = await probe.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken)).Should().Be(Healthy);
    }

    // An anonymous endpoint that runs every check on each call needs a short output cache, so probes can't overload it.
    [Theory]
    [InlineData(Alive)]
    [InlineData(Health)]
    public async Task ASecondProbeWithinTheCacheWindowIsServedFromTheCache(string path)
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production);
        using HttpClient probe = app.CreateClient(signedIn: false);
        using HttpResponseMessage first = await probe.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);

        using HttpResponseMessage second = await probe.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);

        second.Headers.Age.Should().NotBeNull("the second probe within the cache window is served from the output cache");
    }

    // Each endpoint is time-boxed, by any of the ways ASP.NET Core documents (a named or inline timeout, a policy, or
    // the default policy); the test below sees a timeout cut a slow check off, through /health.
    [Theory]
    [InlineData(Alive)]
    [InlineData(Health)]
    public void AHealthEndpointIsTimeBoxed(string path)
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production);

        Endpoint endpoint = app.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .Single(candidate => (candidate as RouteEndpoint)?.RoutePattern.RawText == path);

        IsTimeBoxed(endpoint, app.Services.GetRequiredService<IOptions<RequestTimeoutOptions>>().Value)
            .Should().BeTrue("an anonymous endpoint that probes call often is time-boxed");
    }

    // A check that waits 30 seconds meets every request timeout policy shortened to 100 ms, so the test stays fast
    // whatever the app names its policy. (The timeout middleware doesn't fire under a debugger.)
    [Fact]
    public async Task ASlowHealthCheckIsCutOffWithAGatewayTimeout()
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production, services =>
        {
            services.AddHealthChecks().AddAsyncCheck("kit-slow", async cancellationToken =>
            {
                await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken);
                return HealthCheckResult.Healthy();
            });
            services.PostConfigure<RequestTimeoutOptions>(ShortenEveryPolicy);
        });
        using HttpClient probe = app.CreateClient(signedIn: false);
        Stopwatch elapsed = Stopwatch.StartNew();

        using HttpResponseMessage response = await probe.GetAsync(s_health, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.GatewayTimeout);
        elapsed.Elapsed.Should().BeLessThan(TimeSpan.FromSeconds(10));
    }

    // A failing dependency takes the app out of rotation, but a liveness check that ran it would restart the app.
    [Fact]
    public async Task AliveStaysHealthyWhileAReadinessCheckFails()
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production, services => services.AddHealthChecks()
            .AddCheck("kit-dependency", () => HealthCheckResult.Unhealthy("down")));
        using HttpClient probe = app.CreateClient(signedIn: false);
        using HttpResponseMessage health = await probe.GetAsync(s_health, TestContext.Current.CancellationToken);

        using HttpResponseMessage alive = await probe.GetAsync(s_alive, TestContext.Current.CancellationToken);

        health.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        alive.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    private static bool IsTimeBoxed(Endpoint endpoint, RequestTimeoutOptions options) =>
        endpoint.Metadata.GetMetadata<DisableRequestTimeoutAttribute>() is null
        && (endpoint.Metadata.GetMetadata<RequestTimeoutAttribute>() is not null
            || endpoint.Metadata.GetMetadata<RequestTimeoutPolicy>() is not null
            || options.DefaultPolicy is not null);

    private static void ShortenEveryPolicy(RequestTimeoutOptions options)
    {
        foreach (string name in options.Policies.Keys.ToList())
        {
            options.AddPolicy(name, TimeSpan.FromMilliseconds(100));
        }

        options.DefaultPolicy = options.DefaultPolicy is null ? null : new RequestTimeoutPolicy { Timeout = TimeSpan.FromMilliseconds(100) };
    }
}
