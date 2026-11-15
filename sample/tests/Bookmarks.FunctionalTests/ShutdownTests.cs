using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// Graceful shutdown (OPS-005): when the platform sends SIGTERM, the host cancels its stopping token and gives
/// in-flight work its shutdown timeout to finish, which must end before the platform's own grace period does (30
/// seconds by default on Kubernetes) and it kills the process.
/// </summary>
public sealed class ShutdownTests : IDisposable
{
    private readonly ApiHost _host = new("Production");

    public void Dispose() => _host.Dispose();

    [Fact]
    public void TheShutdownTimeoutEndsBeforeThePlatformsGracePeriod()
    {
        HostOptions options = _host.Services.GetRequiredService<IOptions<HostOptions>>().Value;

        options.ShutdownTimeout.Should().BePositive().And.BeLessThan(TimeSpan.FromSeconds(30));
    }
}
