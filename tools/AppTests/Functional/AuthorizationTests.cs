using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace Kit.AppTests.Functional;

/// <summary>
/// Sign-in is required by default (SEC-007): a fallback authorization policy that requires a signed-in user, and only
/// the endpoints the app lists in its part of <see cref="AppHost"/> opt out with AllowAnonymous.
/// </summary>
public sealed class AuthorizationTests
{
    [Fact]
    public void TheFallbackPolicyRequiresASignedInUser()
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production);

        AuthorizationPolicy? fallback = app.Services.GetRequiredService<IOptions<AuthorizationOptions>>().Value.FallbackPolicy;

        fallback.Should().NotBeNull("an endpoint that forgets its authorization would otherwise be public");
        fallback!.Requirements.Should().ContainItemsAssignableTo<DenyAnonymousAuthorizationRequirement>();
    }

    // An endpoint added to the app's list is a decision, made in review, that the whole internet may call it.
    [Fact]
    public void OnlyTheEndpointsTheAppListsAllowAnonymousCallers()
    {
        using IAppUnderTest app = AppHost.Start(Environments.Development);

        IEnumerable<string?> anonymous = app.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(endpoint => endpoint.Metadata.GetMetadata<IAllowAnonymous>() is not null)
            .Select(endpoint => endpoint.RoutePattern.RawText);

        anonymous.Should().BeEquivalentTo(AppHost.AnonymousRoutes);
    }
}
