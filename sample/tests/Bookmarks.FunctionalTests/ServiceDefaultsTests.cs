using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Timeouts;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using OpenTelemetry.Instrumentation.AspNetCore;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The service defaults every ASP.NET Core app gets (OPS-001 to OPS-003, ADR-0037): health endpoints, OpenTelemetry
/// and HTTP resilience, from the Bookmarks.ServiceDefaults project.
/// </summary>
public sealed class ServiceDefaultsTests : IDisposable
{
    // The HttpClient names the OTLP exporter documents for its trace, metric and log exporters.
    private static readonly string[] s_otlpClients = ["OtlpTraceExporter", "OtlpMetricExporter", "OtlpLogExporter"];

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
        endpoint.Metadata.GetMetadata<RequestTimeoutAttribute>()?.PolicyName.Should().Be("HealthChecks");

        using HttpResponseMessage first = await _host.Client.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);
        using HttpResponseMessage second = await _host.Client.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);

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
        Stopwatch elapsed = Stopwatch.StartNew();

        using HttpResponseMessage response = await host.Client.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.GatewayTimeout);
        elapsed.Elapsed.Should().BeLessThan(TimeSpan.FromSeconds(10));
    }

    [Fact]
    public void OpenTelemetryCollectsTracesMetricsAndLogs()
    {
        _host.Services.GetService<TracerProvider>().Should().NotBeNull("traces are collected");
        _host.Services.GetService<MeterProvider>().Should().NotBeNull("metrics are collected");
        _host.Services.GetServices<ILoggerProvider>().Select(provider => provider.GetType().Name)
            .Should().Contain("OpenTelemetryLoggerProvider", "logs go through OpenTelemetry too");
    }

    [Theory]
    [InlineData("http://127.0.0.1:9", true)]
    [InlineData(null, false)]
    public async Task TracesAreExportedOverOtlpOnlyWhenAnEndpointIsSet(string? endpoint, bool exported)
    {
        // Review 1 of PR 21: traces leave the app only with OTEL_EXPORTER_OTLP_ENDPOINT set. The exporter sends them
        // through the named HttpClient "OtlpTraceExporter", which its README documents for this (v1.20.1, "Configure
        // HttpClient"), so a recording handler sees each export without a collector. Without an endpoint, the
        // exporter's default (localhost:4318 over http/protobuf) would go through the same client if it existed.
        using RecordingHandler collector = new();
        Dictionary<string, string> settings = new() { ["OTEL_EXPORTER_OTLP_PROTOCOL"] = "http/protobuf" };
        if (endpoint is not null)
        {
            settings["OTEL_EXPORTER_OTLP_ENDPOINT"] = endpoint;
        }

        // Metrics and logs go to the recorder too, through their own documented client names, so nothing reaches the
        // network.
        using ApiHost host = new(settings: settings, services: services =>
        {
            foreach (string client in s_otlpClients)
            {
                services.AddHttpClient(client).ConfigurePrimaryHttpMessageHandler(() => collector);
            }
        });

        // A span from the app's own source, which the service defaults trace, ended before the flush, so the flush
        // has a finished span to export whatever the timing of the host.
        TracerProvider tracing = host.Services.GetRequiredService<TracerProvider>();
        using (ActivitySource source = new(host.Services.GetRequiredService<IHostEnvironment>().ApplicationName))
        using (Activity? span = source.StartActivity("work"))
        {
            span.Should().NotBeNull("the app's own source is traced");
        }

        tracing.ForceFlush(10_000).Should().BeTrue();

        if (exported)
        {
            collector.Paths.Should().Contain("/v1/traces", "an OTLP endpoint is set");
        }
        else
        {
            collector.Paths.Should().BeEmpty("no OTLP endpoint is set");
        }
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

    [Fact]
    public async Task AliveStaysHealthyWhileAReadinessCheckFails()
    {
        // Mutation testing (PR 23): with /alive's predicate removed it ran every check, so a failing dependency
        // would restart a running app instead of only taking it out of rotation.
        using ApiHost host = new(services: services => services.AddHealthChecks()
            .AddCheck("dependency", () => HealthCheckResult.Unhealthy("down")));

        using HttpResponseMessage health = await host.Client.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);
        using HttpResponseMessage alive = await host.Client.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        health.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        alive.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public void LogsKeepTheirFormattedMessageAndScopes()
    {
        // Mutation testing (PR 23): nothing noticed when OpenTelemetry logs lost the formatted message or scopes.
        OpenTelemetry.Logs.OpenTelemetryLoggerOptions logging = _host.Services
            .GetRequiredService<IOptionsMonitor<OpenTelemetry.Logs.OpenTelemetryLoggerOptions>>().CurrentValue;

        logging.IncludeFormattedMessage.Should().BeTrue();
        logging.IncludeScopes.Should().BeTrue();
    }

    [Fact]
    public void TheServiceDefaultsRejectAMissingBuilderOrAppByName()
    {
        // Mutation testing (PR 23): without the guards, a null failed later with a NullReferenceException.
        ((Action)(() => ServiceDefaultsExtensions.AddServiceDefaults<IHostApplicationBuilder>(null!)))
            .Should().Throw<ArgumentNullException>().WithParameterName("builder");
        ((Action)(() => ServiceDefaultsExtensions.ConfigureOpenTelemetry<IHostApplicationBuilder>(null!)))
            .Should().Throw<ArgumentNullException>().WithParameterName("builder");
        ((Action)(() => ServiceDefaultsExtensions.MapDefaultEndpoints(null!)))
            .Should().Throw<ArgumentNullException>().WithParameterName("app");
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

    /// <summary>
    /// An OTLP collector that answers 200 and records the path of each export it gets. The exporter sends
    /// synchronously, so the handler overrides Send as well as SendAsync, as the exporter's HttpClientFactory
    /// documentation asks of custom handlers.
    /// </summary>
    private sealed class RecordingHandler : HttpMessageHandler
    {
        private readonly ConcurrentQueue<string> _paths = new();

        public IReadOnlyCollection<string> Paths => _paths;

        protected override HttpResponseMessage Send(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            _paths.Enqueue(request.RequestUri!.AbsolutePath);
            return new HttpResponseMessage(HttpStatusCode.OK);
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(Send(request, cancellationToken));
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
