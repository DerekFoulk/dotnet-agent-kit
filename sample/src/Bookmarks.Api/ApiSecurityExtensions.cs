using System.Security.Claims;
using Bookmarks.Domain;
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
                .RequireAssertion(context => IsOwnerId(context.User.FindFirstValue(JwtRegisteredClaimNames.Sub)))
                .Build());
        return services;
    }

    // A sub that's there but blank would make every such caller one shared owner, and one past OpenID Connect's 255
    // characters can't be an owner: both are the token's fault, so a 403 on every endpoint.
    private static bool IsOwnerId(string? sub) => !string.IsNullOrWhiteSpace(sub) && sub.Length <= Bookmark.MaxOwnerIdLength;

    /// <summary>The signed-in user's id: the token's sub claim, which the fallback policy requires to be a valid owner id.</summary>
    public static string UserId(this ClaimsPrincipal user) =>
        user.FindFirstValue(JwtRegisteredClaimNames.Sub)
        ?? throw new InvalidOperationException("The fallback policy lets no request without a sub claim through.");
}
