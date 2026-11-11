using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// Issues access tokens for the tests, the way an OpenID Connect provider would: RS256-signed, with an issuer, an
/// audience and a lifetime (SEC-008, ADR-0046). The signing key is made in memory for each test run, so no key is
/// ever stored; <see cref="ApiHost"/> tells the API's real JWT bearer handler to trust it, as a real app trusts its
/// provider's published keys.
/// </summary>
internal static class TestTokens
{
    public const string Issuer = "https://login.example.test/";
    public const string Audience = "api://bookmarks-tests";

    /// <summary>The key the API trusts.</summary>
    public static SecurityKey SigningKey { get; } = NewKey();

    /// <summary>A valid token for the given user (the sub claim), or with the given changes.</summary>
    public static string For(
        string? user = "alice", string issuer = Issuer, string audience = Audience, TimeSpan? expiresIn = null,
        SecurityKey? key = null, bool signed = true)
    {
        DateTime now = DateTime.UtcNow;
        DateTime expires = now + (expiresIn ?? TimeSpan.FromMinutes(5));
        SecurityTokenDescriptor descriptor = new()
        {
            Issuer = issuer,
            Audience = audience,
            // An expired token was also issued in the past, so its times stay in order.
            IssuedAt = expires < now ? expires.AddMinutes(-5) : now,
            NotBefore = expires < now ? expires.AddMinutes(-5) : now,
            Expires = expires,
            Subject = new ClaimsIdentity(user is null ? [] : [new Claim(JwtRegisteredClaimNames.Sub, user)]),
            SigningCredentials = signed ? new SigningCredentials(key ?? SigningKey, SecurityAlgorithms.RsaSha256) : null,
        };
        return new JsonWebTokenHandler().CreateToken(descriptor);
    }

    /// <summary>A key the API doesn't trust.</summary>
    public static SecurityKey NewKey()
    {
        // The key keeps the RSA parameters, not the RSA object, so nothing is left to dispose.
        using RSA rsa = RSA.Create(2048);
        return new RsaSecurityKey(rsa.ExportParameters(includePrivateParameters: true)) { KeyId = Guid.NewGuid().ToString("N") };
    }
}
