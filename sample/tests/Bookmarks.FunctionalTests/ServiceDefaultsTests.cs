using System.Net;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The service defaults every ASP.NET Core app gets (OPS-001 to OPS-003, ADR-0037): health endpoints, OpenTelemetry
/// and HTTP resilience, from the Bookmarks.ServiceDefaults project.
/// </summary>
public sealed class ServiceDefaultsTests : IDisposable
{
    private readonly ApiHost _host = new();

    [Fact]
    public async Task AliveAnswersHealthyWhenTheAppIsRunning()
    {
        using HttpResponseMessage response = await _host.Client.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken)).Should().Be("Healthy");
    }

    [Fact]
    public async Task HealthAnswersHealthyAndChecksTheDatabaseButAliveDoesNot()
    {
        using HttpResponseMessage response = await _host.Client.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);

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

        using HttpResponseMessage response = await production.Client.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken)).Should().Be("Healthy");
    }

    [Fact]
    public void OpenTelemetryCollectsTracesMetricsAndLogs()
    {
        // By type name, so the test doesn't depend on the OpenTelemetry packages itself (OPS-001).
        Type? tracerProvider = Type.GetType("OpenTelemetry.Trace.TracerProvider, OpenTelemetry.Api");
        Type? meterProvider = Type.GetType("OpenTelemetry.Metrics.MeterProvider, OpenTelemetry.Api");

        tracerProvider.Should().NotBeNull("the app should reference OpenTelemetry");
        _host.Services.GetService(tracerProvider!).Should().NotBeNull("traces are collected");
        _host.Services.GetService(meterProvider!).Should().NotBeNull("metrics are collected");
        _host.Services.GetServices<ILoggerProvider>().Select(provider => provider.GetType().Name)
            .Should().Contain("OpenTelemetryLoggerProvider", "logs go through OpenTelemetry too");
    }

    [Fact]
    public async Task TheAppStillAnswersWithAnOtlpEndpointSet()
    {
        // Telemetry is exported over OTLP only when OTEL_EXPORTER_OTLP_ENDPOINT is set; nothing listens here.
        using ApiHost exporting = new(settings: new Dictionary<string, string> { ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://localhost:4317" });

        using HttpResponseMessage response = await exporting.Client.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    public void Dispose() => _host.Dispose();
}
