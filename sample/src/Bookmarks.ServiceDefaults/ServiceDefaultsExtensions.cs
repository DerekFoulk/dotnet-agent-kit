using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Http.Resilience;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

namespace Microsoft.Extensions.Hosting;

/// <summary>
/// The service defaults every ASP.NET Core app gets (OPS-001 to OPS-003, ADR-0037): OpenTelemetry logs, metrics
/// and traces, health checks with the endpoints that report them, and resilience on every HttpClient.
/// </summary>
/// <remarks>
/// Adapted from Microsoft's aspire-servicedefaults template (Extensions.cs in microsoft/aspire at commit 569ddf4,
/// MIT; see THIRD-PARTY-NOTICES.md). It leaves out service discovery, which the sample doesn't need since it calls
/// no other service, and adds a short cache and a timeout to the health endpoints.
/// </remarks>
public static class ServiceDefaultsExtensions
{
    private const string HealthPath = "/health";
    private const string AlivePath = "/alive";
    private const string LiveTag = "live";
    private const string HealthPolicy = "HealthChecks";

    /// <summary>Adds the service defaults to the app.</summary>
    public static TBuilder AddServiceDefaults<TBuilder>(this TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ConfigureOpenTelemetry();
        // Liveness: the process answers. It checks nothing else, so a slow dependency never restarts the app.
        builder.Services.AddHealthChecks().AddCheck("self", () => HealthCheckResult.Healthy(), [LiveTag]);
        // Every HttpClient gets timeouts, retries with backoff and a circuit breaker (OPS-003). Retries are only for
        // safe methods: a POST, PUT, PATCH or DELETE isn't repeated, so a payment can't be sent twice (review 1
        // of PR 21). A client that needs other settings calls RemoveAllResilienceHandlers() before adding its
        // own; adding a second handler on top would keep this one's retries. That method is experimental
        // (EXTEXP0001), so the call needs the diagnostic suppressed, with a reason.
        builder.Services.ConfigureHttpClientDefaults(http =>
            http.AddStandardResilienceHandler(options => options.Retry.DisableForUnsafeHttpMethods()));
        // The health endpoints are anonymous, so a flood of probes mustn't become a flood of database calls: a
        // Healthy answer is cached briefly (output caching stores only 200 responses), and a slow check is cut off
        // with a 504. The settings follow Microsoft's Aspire health-check guidance (aspire.dev, MIT).
        builder.Services.AddRequestTimeouts(timeouts => timeouts.AddPolicy(HealthPolicy, TimeSpan.FromSeconds(5)));
        builder.Services.AddOutputCache(caching => caching.AddPolicy(HealthPolicy, policy => policy.Expire(TimeSpan.FromSeconds(10))));
        return builder;
    }

    /// <summary>
    /// Sends logs, metrics and traces through OpenTelemetry, and exports them over OTLP when
    /// OTEL_EXPORTER_OTLP_ENDPOINT is set (for example to the Aspire dashboard, or a collector in production).
    /// </summary>
    public static TBuilder ConfigureOpenTelemetry<TBuilder>(this TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.Logging.AddOpenTelemetry(logging =>
        {
            logging.IncludeFormattedMessage = true;
            logging.IncludeScopes = true;
        });

        builder.Services.AddOpenTelemetry()
            .WithMetrics(metrics => metrics
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation())
            .WithTracing(tracing => tracing
                .AddSource(builder.Environment.ApplicationName)
                // Probes call the health endpoints often; tracing them would only add noise.
                .AddAspNetCoreInstrumentation(aspNetCore => aspNetCore.Filter = context =>
                    !context.Request.Path.StartsWithSegments(HealthPath, StringComparison.OrdinalIgnoreCase)
                    && !context.Request.Path.StartsWithSegments(AlivePath, StringComparison.OrdinalIgnoreCase))
                .AddHttpClientInstrumentation());

        if (!string.IsNullOrWhiteSpace(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]))
        {
            builder.Services.AddOpenTelemetry().UseOtlpExporter();
        }

        return builder;
    }

    /// <summary>
    /// Maps /health (readiness: every check passes) and /alive (liveness: the "live" checks pass). They answer in
    /// every environment, because production probes need them, with only the status word ("Healthy",
    /// "Degraded" or "Unhealthy"), never the checks' details. A Healthy answer is cached for 10 seconds, and a
    /// check that takes longer than 5 seconds is cut off with an empty 504.
    /// </summary>
    /// <remarks>
    /// This adds the output-cache and request-timeout middleware. Call UseCors, UseAuthentication and
    /// UseAuthorization before this method: output caching must run after them, or it could serve an answer
    /// cached for an authorized caller to an anonymous one.
    /// </remarks>
    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);

        app.UseRequestTimeouts();
        app.UseOutputCache();
        RouteGroupBuilder health = app.MapGroup(string.Empty);
        health.CacheOutput(HealthPolicy).WithRequestTimeout(HealthPolicy);
        health.MapHealthChecks(HealthPath);
        health.MapHealthChecks(AlivePath, new HealthCheckOptions { Predicate = registration => registration.Tags.Contains(LiveTag) });
        return app;
    }
}
