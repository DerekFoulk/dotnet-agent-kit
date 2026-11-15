using Bookmarks.Application.Features.Bookmarks;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The container checks its registrations in every environment, not only in Development (CRF-013): Microsoft's
/// dependency injection guidelines warn against resolving a scoped service from the root and against a singleton that
/// captures one, and ValidateScopes and ValidateOnBuild find both.
/// </summary>
public sealed class DependencyInjectionTests
{
    [Fact]
    public void ASingletonThatCapturesAScopedServiceStopsTheAppInProduction()
    {
        Action start = () =>
        {
            // BookmarkService as a singleton would hold the scoped repository, and its DbContext, for the app's lifetime.
            using ApiHost host = new("Production", services: services => services.AddSingleton<BookmarkService>());
        };

        start.Should().Throw<AggregateException>()
            .WithInnerException<InvalidOperationException>().WithMessage("*scoped service*singleton*");
    }

    [Fact]
    public void AScopedServiceCantBeResolvedFromTheRootInProduction()
    {
        using ApiHost host = new("Production");

        Action resolve = () => host.Services.GetRequiredService<BookmarkService>();

        resolve.Should().Throw<InvalidOperationException>().WithMessage("*scoped service*root provider*");
    }
}
