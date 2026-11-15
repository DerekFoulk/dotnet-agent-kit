using Bookmarks.Application.Features.Bookmarks;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The tests catch a misregistered service in every environment they run the app in, not only in Development
/// (CRF-013). Microsoft's dependency injection guidelines warn against a singleton that captures a scoped service and
/// against resolving a scoped service from the root; ApiHost turns ValidateScopes and ValidateOnBuild on, which find
/// both. The app itself keeps ASP.NET Core's default, which checks only in Development.
/// </summary>
public sealed class DependencyInjectionTests
{
    [Fact]
    public void TheTestsCatchASingletonThatCapturesAScopedServiceInProduction()
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
    public void TheTestsCatchAScopedServiceResolvedFromTheRootInProduction()
    {
        using ApiHost host = new("Production");

        Action resolve = () => host.Services.GetRequiredService<BookmarkService>();

        resolve.Should().Throw<InvalidOperationException>().WithMessage("*scoped service*root provider*");
    }
}
