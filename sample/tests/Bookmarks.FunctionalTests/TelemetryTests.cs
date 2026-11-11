using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using OpenTelemetry.Instrumentation.AspNetCore;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

namespace Bookmarks.FunctionalTests;

/// <summary>The OpenTelemetry logs, metrics and traces the service defaults set up (OPS-001, ADR-0037).</summary>
public sealed class TelemetryTests : IDisposable
{
    // The HttpClient names the OTLP exporter documents for its trace, metric and log exporters.
    private static readonly string[] s_otlpClients = ["OtlpTraceExporter", "OtlpMetricExporter", "OtlpLogExporter"];

    private readonly ApiHost _host = new();

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
    public void TracesAreExportedOverOtlpOnlyWhenAnEndpointIsSet(string? endpoint, bool exported)
    {
        // Review 1 of PR 21: traces leave the app only with OTEL_EXPORTER_OTLP_ENDPOINT set. The exporter sends them
        // through the named HttpClient "OtlpTraceExporter", which its README documents for this (v1.20.1, "Configure
        // HttpClient"), so a recording handler sees each export without a collector. If the app added the exporter
        // without an endpoint, its default (localhost:4318 over http/protobuf) would go through the same client.
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
    public void LogsKeepTheirFormattedMessageAndScopes()
    {
        // Mutation testing (PR 23): nothing noticed when OpenTelemetry logs lost the formatted message or scopes.
        OpenTelemetryLoggerOptions logging = _host.Services.GetRequiredService<IOptionsMonitor<OpenTelemetryLoggerOptions>>().CurrentValue;

        logging.IncludeFormattedMessage.Should().BeTrue();
        logging.IncludeScopes.Should().BeTrue();
    }

    public void Dispose() => _host.Dispose();

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
}
