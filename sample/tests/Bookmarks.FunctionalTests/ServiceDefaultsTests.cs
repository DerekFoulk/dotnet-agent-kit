using Microsoft.Extensions.Hosting;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The service defaults' entry points (OPS-001 to OPS-003, ADR-0037). What they set up is tested by concern:
/// <see cref="HealthEndpointTests"/>, <see cref="TelemetryTests"/> and <see cref="ResilienceTests"/>.
/// </summary>
public sealed class ServiceDefaultsTests
{
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
}
