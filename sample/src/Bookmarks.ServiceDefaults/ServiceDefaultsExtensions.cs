using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Microsoft.Extensions.Hosting;

/// <summary>
/// The service defaults every ASP.NET Core app gets (OPS-001 to OPS-003, ADR-0037): health checks, and the
/// endpoints that report them.
/// </summary>
public static class ServiceDefaultsExtensions
{
    private const string HealthPath = "/health";
    private const string AlivePath = "/alive";
    private const string LiveTag = "live";

    /// <summary>Adds the service defaults to the app.</summary>
    public static TBuilder AddServiceDefaults<TBuilder>(this TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);

        // Liveness: the process answers. It checks nothing else, so a slow dependency never restarts the app.
        builder.Services.AddHealthChecks().AddCheck("self", () => HealthCheckResult.Healthy(), [LiveTag]);
        return builder;
    }

    /// <summary>
    /// Maps /health (readiness: every check passes) and /alive (liveness: the "live" checks pass). They answer in
    /// every environment, because production probes need them, with only the status word ("Healthy",
    /// "Degraded" or "Unhealthy"), never the checks' details.
    /// </summary>
    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);

        app.MapHealthChecks(HealthPath);
        app.MapHealthChecks(AlivePath, new HealthCheckOptions { Predicate = registration => registration.Tags.Contains(LiveTag) });
        return app;
    }
}
