using System.Diagnostics;
using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Timeouts;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;

namespace Bookmarks.FunctionalTests;

/// <summary>The health endpoints the service defaults map (OPS-002, ADR-0037).</summary>
public sealed class HealthEndpointTests : IDisposable
{
    private readonly ApiHost _host = new();
    private readonly HttpClient _probe;

    // Probes call without a token, so every test here does too (SEC-007: the health endpoints are anonymous).
    public HealthEndpointTests() => _probe = _host.CreateClient(token: null);

    [Fact]
    public async Task AliveAnswersHealthyWhenTheAppIsRunning()
    {
        using HttpResponseMessage response = await _probe.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken)).Should().Be("Healthy");
    }

    [Fact]
    public async Task HealthAnswersHealthyAndChecksTheDatabaseButAliveDoesNot()
    {
        using HttpResponseMessage response = await _probe.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken)).Should().Be("Healthy");
        // Readiness includes the database; liveness doesn't, so a slow database never restarts the app.
        HealthCheckRegistration database = _host.Services.GetRequiredService<IOptions<HealthCheckServiceOptions>>().Value.Registrations
            .Should().ContainSingle(registration => registration.Name == "BookmarksDbContext").Subject;
        database.Tags.Should().NotContain("live");
    }

    [Theory]
    [InlineData("/alive")]
    [InlineData("/health")]
    public async Task HealthEndpointsAnswerInProductionWithTheStatusOnly(string path)
    {
        // Probes need them in production; the default response is the status word, with no details.
        using ApiHost production = new("Production");
        using HttpClient probe = production.CreateClient(token: null);

        using HttpResponseMessage response = await probe.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken)).Should().Be("Healthy");
    }

    [Theory]
    [InlineData("/alive")]
    [InlineData("/health")]
    public async Task HealthEndpointsAreCachedAndTimeBoxedSoProbesCanNotOverloadTheApp(string path)
    {
        // Review 1 of PR 21, after Microsoft's Aspire health-check guidance: an anonymous /health that touches the
        // database on every call needs a request timeout and a short output cache.
        Endpoint endpoint = _host.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .Single(candidate => (candidate as RouteEndpoint)?.RoutePattern.RawText == path);
        endpoint.Metadata.GetMetadata<RequestTimeoutAttribute>().Should().NotBeNull("every health endpoint is time-boxed")
            .And.Subject.As<RequestTimeoutAttribute>().PolicyName.Should().Be("HealthChecks");

        using HttpResponseMessage first = await _probe.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);
        using HttpResponseMessage second = await _probe.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);

        second.Headers.Age.Should().NotBeNull("the second probe within the cache window is served from the output cache");
    }

    [Fact]
    public void TheHealthTimeoutIsFiveSeconds()
    {
        // Review 3 of PR 21: the slow-check test below shortens the policy, so this pins the value the app uses.
        _host.Services.GetRequiredService<IOptions<RequestTimeoutOptions>>().Value.Policies["HealthChecks"].Timeout
            .Should().Be(TimeSpan.FromSeconds(5));
    }

    [Fact]
    public async Task ASlowHealthCheckIsCutOffByTheTimeout()
    {
        // Review 2 of PR 21: the metadata alone passed with the timeout middleware gone. A check that waits 30 seconds
        // meets a timeout shortened to 100 ms here, so the test stays fast. (The middleware doesn't fire under a
        // debugger, so run this one without one.)
        using ApiHost host = new(services: services =>
        {
            services.AddHealthChecks().AddAsyncCheck("slow", async cancellationToken =>
            {
                await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken);
                return HealthCheckResult.Healthy();
            });
            services.PostConfigure<RequestTimeoutOptions>(options => options.AddPolicy("HealthChecks", TimeSpan.FromMilliseconds(100)));
        });
        using HttpClient probe = host.CreateClient(token: null);
        Stopwatch elapsed = Stopwatch.StartNew();

        using HttpResponseMessage response = await probe.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.GatewayTimeout);
        elapsed.Elapsed.Should().BeLessThan(TimeSpan.FromSeconds(10));
    }

    [Fact]
    public void AliveRestsOnALiveCheckOfItsOwn()
    {
        // Review 1 of PR 21: with no live check at all, /alive would still answer Healthy, so this pins the check.
        _host.Services.GetRequiredService<IOptions<HealthCheckServiceOptions>>().Value.Registrations
            .Should().ContainSingle(registration => registration.Name == "self").Which.Tags.Should().Contain("live");
    }

    [Fact]
    public async Task AliveStaysHealthyWhileAReadinessCheckFails()
    {
        // Mutation testing (PR 23): with /alive's predicate removed it ran every check, so a failing dependency
        // would restart a running app instead of only taking it out of rotation.
        using ApiHost host = new(services: services => services.AddHealthChecks()
            .AddCheck("dependency", () => HealthCheckResult.Unhealthy("down")));
        using HttpClient probe = host.CreateClient(token: null);

        using HttpResponseMessage health = await probe.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);
        using HttpResponseMessage alive = await probe.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        health.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        alive.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    public void Dispose()
    {
        _probe.Dispose();
        _host.Dispose();
    }
}
