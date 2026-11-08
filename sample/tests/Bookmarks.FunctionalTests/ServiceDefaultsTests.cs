using System.Diagnostics;
using System.Net;
using System.Reflection;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Timeouts;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using OpenTelemetry.Instrumentation.AspNetCore;

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

    [Theory]
    [InlineData("/alive")]
    [InlineData("/health")]
    public async Task HealthEndpointsAreCachedAndTimeBoxedSoProbesCanNotOverloadTheApp(string path)
    {
        // Review 1 of PR 21, after Microsoft's Aspire health-check guidance: an anonymous /health that touches the
        // database on every call needs a request timeout and a short output cache.
        Endpoint endpoint = _host.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .Single(candidate => (candidate as RouteEndpoint)?.RoutePattern.RawText == path);
        endpoint.Metadata.Select(metadata => metadata.GetType().Name).Should().Contain(name => name.Contains("RequestTimeout", StringComparison.Ordinal));

        using HttpResponseMessage first = await _host.Client.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);
        using HttpResponseMessage second = await _host.Client.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);

        second.Headers.Age.Should().NotBeNull("the second probe within the cache window is served from the output cache");
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
        Stopwatch elapsed = Stopwatch.StartNew();

        using HttpResponseMessage response = await host.Client.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.GatewayTimeout);
        elapsed.Elapsed.Should().BeLessThan(TimeSpan.FromSeconds(10));
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
    public async Task TracesAreExportedOverOtlpOnlyWhenAnEndpointIsSet()
    {
        // Review 1 of PR 21: the tracer provider gets an export processor only with OTEL_EXPORTER_OTLP_ENDPOINT set.
        // Its Processor property isn't public, so it's read by reflection; nothing listens on the endpoint here.
        using ApiHost exporting = new(settings: new Dictionary<string, string> { ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://localhost:4317" });

        using HttpResponseMessage response = await exporting.Client.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        TraceProcessor(exporting).Should().Contain("Export", "an OTLP endpoint is set");
        TraceProcessor(_host).Should().BeNull("no OTLP endpoint is set");
    }

    [Theory]
    [InlineData("/health", false)]
    [InlineData("/alive", false)]
    [InlineData("/bookmarks", true)]
    public void HealthProbesAreNotTracedButOtherRequestsAre(string path, bool traced)
    {
        // Review 1 of PR 21: probes call the health endpoints often, so the trace filter leaves them out.
        Func<HttpContext, bool>? filter = _host.Services.GetRequiredService<IOptionsMonitor<AspNetCoreTraceInstrumentationOptions>>()
            .Get(Options.DefaultName).Filter;
        DefaultHttpContext context = new();
        context.Request.Path = path;

        filter.Should().NotBeNull();
        filter!(context).Should().Be(traced);
    }

    [Fact]
    public void AliveRestsOnALiveCheckOfItsOwn()
    {
        // Review 1 of PR 21: with no live check at all, /alive would still answer Healthy, so this pins the check.
        _host.Services.GetRequiredService<IOptions<HealthCheckServiceOptions>>().Value.Registrations
            .Should().ContainSingle(registration => registration.Name == "self").Which.Tags.Should().Contain("live");
    }

    private static string? TraceProcessor(ApiHost host)
    {
        object? provider = host.Services.GetService(Type.GetType("OpenTelemetry.Trace.TracerProvider, OpenTelemetry.Api")!);
        object? processor = provider?.GetType().GetProperty("Processor", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(provider);
        return processor?.GetType().Name;
    }

    [Fact]
    public void EveryHttpClientGetsTheStandardResilienceHandler()
    {
        // Timeouts, retries with backoff and a circuit breaker on every outbound call, by default (OPS-003).
        IHttpMessageHandlerFactory? factory = _host.Services.GetService<IHttpMessageHandlerFactory>();
        factory.Should().NotBeNull("the service defaults set up IHttpClientFactory with resilience");
        using HttpMessageHandler handler = factory!.CreateHandler("any-client");
        List<string> chain = [];
        for (HttpMessageHandler? current = handler; current is not null; current = (current as DelegatingHandler)?.InnerHandler)
        {
            chain.Add(current.GetType().Name);
        }

        chain.Should().Contain("ResilienceHandler");
    }

    [Fact]
    public async Task AFailedPostIsNotRetriedSoItCanNotBeSentTwice()
    {
        // Review 1 of PR 21: the standard handler retries every method by default, so a payment POST could be
        // sent twice. The defaults retry only safe methods.
        using FailingHandler server = new();
        using ApiHost host = new(services: services => services.AddHttpClient("payments").ConfigurePrimaryHttpMessageHandler(() => server));
        using HttpClient client = host.Services.GetRequiredService<IHttpClientFactory>().CreateClient("payments");

        using HttpResponseMessage response = await client.PostAsync(new Uri("https://payments.example/charge"), null, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        server.Calls.Should().Be(1, "a POST isn't safe to repeat");
    }

    /// <summary>A server that always answers 503, counting the calls it gets.</summary>
    private sealed class FailingHandler : HttpMessageHandler
    {
        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable));
        }
    }

    public void Dispose() => _host.Dispose();
}
