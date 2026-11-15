using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.IdentityModel.JsonWebTokens;

namespace Bookmarks.Api;

/// <summary>
/// The parts of Microsoft's Kestrel production security checklist the app sets itself (SEC-011): no Server header, a
/// request body cap, and a rate limit per caller. Host filtering reads AllowedHosts from configuration, and HSTS is
/// on outside Development (Program.cs).
/// </summary>
internal static class ApiHostingExtensions
{
    /// <summary>
    /// The largest request body Kestrel reads, in bytes. A bookmark is a URL of at most 2,048 characters and a title of
    /// at most 500, so 64 KB leaves room and is far under Kestrel's 30 MB default.
    /// </summary>
    public const long MaxRequestBodyBytes = 64 * 1024;

    /// <summary>
    /// Kestrel sends no Server header, which only tells an attacker what to target, and reads at most
    /// <see cref="MaxRequestBodyBytes"/>; and each caller gets a rate limit (<see cref="AddApiRateLimiting"/>).
    /// </summary>
    public static WebApplicationBuilder AddApiHosting(this WebApplicationBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);
        builder.WebHost.ConfigureKestrel(kestrel =>
        {
            kestrel.AddServerHeader = false;
            kestrel.Limits.MaxRequestBodySize = MaxRequestBodyBytes;
        });
        builder.Services.AddApiRateLimiting(builder.Configuration.GetSection("RateLimiting").Get<RateLimitSettings>() ?? new RateLimitSettings());
        return builder;
    }

    /// <summary>
    /// HSTS tells browsers to reach the app over HTTPS only. Not in Development, where the browser would remember it for
    /// localhost.
    /// </summary>
    public static WebApplication UseApiHsts(this WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);
        if (!app.Environment.IsDevelopment())
        {
            app.UseHsts();
        }

        return app;
    }

    /// <summary>
    /// Each caller, a signed-in user by their sub claim and anyone else by IP address, gets a token bucket: a burst of
    /// RateLimiting:BurstLimit requests and RateLimiting:RequestsPerSecond more each second. Over it, the answer is 429
    /// Too Many Requests, which status code pages turn into Problem Details (OWASP API4, unrestricted resource
    /// consumption).
    /// </summary>
    private static void AddApiRateLimiting(this IServiceCollection services, RateLimitSettings settings)
    {
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
                RateLimitPartition.GetTokenBucketLimiter(Caller(context), _ => new TokenBucketRateLimiterOptions
                {
                    TokenLimit = settings.BurstLimit,
                    TokensPerPeriod = settings.RequestsPerSecond,
                    ReplenishmentPeriod = TimeSpan.FromSeconds(1),
                    QueueLimit = 0,
                    AutoReplenishment = true,
                }));
        });
    }

    private static string Caller(HttpContext context) =>
        context.User.FindFirstValue(JwtRegisteredClaimNames.Sub) is { } sub
            ? "user:" + sub
            : "ip:" + context.Connection.RemoteIpAddress;

    /// <summary>
    /// The rate limit's settings. The defaults let the sample's load test (ten users on one token, about 40 requests a
    /// second) through, while a flood from one caller is cut off.
    /// </summary>
    private sealed class RateLimitSettings
    {
        public int BurstLimit { get; init; } = 100;

        public int RequestsPerSecond { get; init; } = 50;
    }
}
