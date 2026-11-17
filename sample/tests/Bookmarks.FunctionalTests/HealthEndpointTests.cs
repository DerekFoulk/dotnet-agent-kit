using System.Diagnostics;
using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Timeouts;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The sample's own parts of its health endpoints (OPS-002, ADR-0037): its database check, its live check and its
/// timeout. The kit's shared HealthTests (tools/AppTests/Functional) check what every app's endpoints do.
/// </summary>
public sealed class HealthEndpointTests : IDisposable
{
    private readonly ApiHost _host = new();
    private readonly HttpClient _probe;

    // Probes call without a token, so every test here does too (SEC-007: the health endpoints are anonymous).
    public HealthEndpointTests() => _probe = _host.CreateClient(token: null);

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

    [Fact]
    public void TheHealthTimeoutIsFiveSeconds()
    {
        // Review 3 of PR 21: the shared slow-check test shortens every policy, so this pins the value the app uses.
        _host.Services.GetRequiredService<IOptions<RequestTimeoutOptions>>().Value.Policies["HealthChecks"].Timeout
            .Should().Be(TimeSpan.FromSeconds(5));
    }

    [Fact]
    public void AliveRestsOnALiveCheckOfItsOwn()
    {
        // Review 1 of PR 21: with no live check at all, /alive would still answer Healthy, so this pins the check.
        _host.Services.GetRequiredService<IOptions<HealthCheckServiceOptions>>().Value.Registrations
            .Should().ContainSingle(registration => registration.Name == "self").Which.Tags.Should().Contain("live");
    }

    public void Dispose()
    {
        _probe.Dispose();
        _host.Dispose();
    }
}
