using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.AppTests.Functional;

/// <summary>A running host's endpoints whose own metadata requires authorization.</summary>
internal static class EndpointAuthorization
{
    /// <summary>
    /// The endpoints that require authorization and don't allow anonymous callers, read from the metadata the
    /// authorization middleware builds a policy from: [Authorize] or RequireAuthorization, a policy, or requirements of
    /// their own (IAuthorizationRequirementData, such as an app's own attribute). MVC's global AuthorizeFilter and the
    /// fallback policy aren't endpoint metadata, so this doesn't see them: the document check leaves them to code review,
    /// and the check of a host that signs nobody in finds the authentication scheme they'd need.
    /// </summary>
    public static IReadOnlyList<RouteEndpoint> Protected(IServiceProvider services) =>
        [.. services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(endpoint => endpoint.Metadata.GetMetadata<IAllowAnonymous>() is null && RequiresAuthorization(endpoint.Metadata))];

    private static bool RequiresAuthorization(EndpointMetadataCollection metadata) =>
        metadata.GetMetadata<IAuthorizeData>() is not null
        || metadata.GetMetadata<AuthorizationPolicy>() is not null
        || metadata.GetMetadata<IAuthorizationRequirementData>() is not null;
}
