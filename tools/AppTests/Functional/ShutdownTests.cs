using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace Kit.AppTests.Functional;

/// <summary>
/// Graceful shutdown (OPS-005): on SIGTERM the host gives in-flight work its shutdown timeout to finish, which must end
/// before the platform's own grace period (30 seconds by default on Kubernetes), when it kills the process.
/// </summary>
public sealed class ShutdownTests
{
    [Theory]
    [EachHost]
    public void TheShutdownTimeoutEndsBeforeThePlatformsGracePeriod(string host)
    {
        using IAppUnderTest app = AppHost.Named(host).Start(Environments.Production);

        HostOptions options = app.Services.GetRequiredService<IOptions<HostOptions>>().Value;

        options.ShutdownTimeout.Should().BePositive().And.BeLessThan(TimeSpan.FromSeconds(30));
    }
}
