using Microsoft.AspNetCore.Authorization;

namespace Bookmarks.Api;

/// <summary>Who may call the API (SEC-007, SEC-008, ADR-0046).</summary>
internal static class ApiSecurityExtensions
{
    /// <summary>
    /// Callers sign in with an OpenID Connect provider and send its access token; the JWT bearer handler checks its
    /// signature, issuer, audience and lifetime, with the settings under Authentication:Schemes:Bearer. Every
    /// endpoint then needs a signed-in user unless it opts out with AllowAnonymous, so a new endpoint is never
    /// public by mistake.
    /// </summary>
    public static IServiceCollection AddApiSecurity(this IServiceCollection services)
    {
        services.AddAuthentication().AddJwtBearer();
        services.AddAuthorizationBuilder()
            .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());
        return services;
    }
}
