using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.JsonWebTokens;

namespace Bookmarks.Api;

/// <summary>Who may call the API (SEC-007 to SEC-009, ADR-0048).</summary>
internal static class ApiSecurityExtensions
{
    /// <summary>
    /// Callers sign in with an OpenID Connect provider and send its access token; the JWT bearer handler checks its
    /// signature, issuer, audience and lifetime, with the settings under Authentication:Schemes:Bearer. Every
    /// endpoint then needs a signed-in user, named by the token's sub claim, unless it opts out with AllowAnonymous,
    /// so a new endpoint is never public by mistake.
    /// </summary>
    public static IServiceCollection AddApiSecurity(this IServiceCollection services)
    {
        // Keep the token's own claim names, so sub stays "sub" instead of a long XML-namespace claim type.
        services.AddAuthentication().AddJwtBearer(options => options.MapInboundClaims = false);
        services.AddAuthorizationBuilder()
            .SetFallbackPolicy(new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser()
                .RequireClaim(JwtRegisteredClaimNames.Sub)
                .Build());
        return services;
    }

    /// <summary>The signed-in user's id: the token's sub claim, which the fallback policy requires.</summary>
    public static string UserId(this ClaimsPrincipal user) =>
        user.FindFirstValue(JwtRegisteredClaimNames.Sub)
        ?? throw new InvalidOperationException("The fallback policy lets no request without a sub claim through.");
}
