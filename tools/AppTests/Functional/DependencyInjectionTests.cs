using System.Diagnostics.CodeAnalysis;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Kit.AppTests.Functional;

/// <summary>
/// The tests catch a misregistered service in every environment they run the app in, not only in Development (CRF-013):
/// the host turns on ValidateScopes and ValidateOnBuild, which find a singleton that captures a scoped service and a
/// scoped service resolved from the root. The app itself keeps ASP.NET Core's default, which checks only in Development.
/// </summary>
public sealed class DependencyInjectionTests
{
    [Fact]
    public void TheTestsCatchASingletonThatCapturesAScopedServiceInProduction()
    {
        Action start = () =>
        {
            using IAppUnderTest app = AppHost.Start(Environments.Production, services => services
                .AddScoped<ScopedProbe>()
                .AddSingleton<CapturingProbe>());
        };

        start.Should().Throw<AggregateException>()
            .WithInnerException<InvalidOperationException>().WithMessage("*scoped service*singleton*");
    }

    [Fact]
    public void TheTestsCatchAScopedServiceResolvedFromTheRootInProduction()
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production, services => services.AddScoped<ScopedProbe>());

        Action resolve = () => app.Services.GetRequiredService<ScopedProbe>();

        resolve.Should().Throw<InvalidOperationException>().WithMessage("*scoped service*root provider*");
    }

    /// <summary>A scoped service, such as a DbContext.</summary>
    [SuppressMessage("Performance", "CA1812:Avoid uninstantiated internal classes", Justification = "Only the container would create it, and the tests check it refuses to; CA1812 can't see that.")]
    private sealed class ScopedProbe;

    /// <summary>A singleton that would hold its scoped dependency for the app's lifetime.</summary>
    [SuppressMessage("Performance", "CA1812:Avoid uninstantiated internal classes", Justification = "The container would create it; ValidateOnBuild refuses first. CA1812 can't see that.")]
    private sealed class CapturingProbe(ScopedProbe scoped)
    {
        public ScopedProbe Scoped { get; } = scoped;
    }
}
