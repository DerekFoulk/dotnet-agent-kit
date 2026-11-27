using System.Diagnostics.CodeAnalysis;
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;
using Microsoft.Extensions.Options;

// A public website with a few signed-in endpoints: anyone may read it, so it sets no fallback authorization policy.
// The admin group requires authorization, and in it the status endpoint allows anonymous callers again. The group is
// mapped without a leading slash, and its feed endpoint answers every method. The staff endpoint requires authorization
// through its own requirement metadata alone (IAuthorizationRequirementData). The OpenAPI document is a fixed file, so
// the Pester test can serve one where the signed-in operations require the Bearer scheme, one where they don't, and
// one that describes only the public operations (KIT_FIXTURE_DOCUMENT). With KIT_FIXTURE_SIGNS_USERS_IN, it signs in
// the caller of any bearer token (AnyBearerToken), as a host whose signature check is off would.
bool signsUsersIn = Environment.GetEnvironmentVariable("KIT_FIXTURE_SIGNS_USERS_IN") == "true";
WebApplicationBuilder builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthorization();
if (signsUsersIn)
{
    builder.Services.AddProblemDetails();
    builder.Services.AddAuthentication(AnyBearerToken.Name)
        .AddScheme<AuthenticationSchemeOptions, AnyBearerToken>(AnyBearerToken.Name, configureOptions: null);
}

WebApplication app = builder.Build();
if (signsUsersIn)
{
    app.UseStatusCodePages();
    app.UseAuthentication();
}

app.UseAuthorization();
app.MapGet("/", () => "Welcome");
RouteGroupBuilder admin = app.MapGroup("admin").RequireAuthorization();
admin.MapPost("notices", () => Results.NoContent());
admin.Map("feed", () => "Feed");
admin.MapGet("status", () => "Open").AllowAnonymous();
app.MapGet("/staff", () => "Staff").WithMetadata(new StaffOnlyAttribute());
string documentName = $"openapi-{Environment.GetEnvironmentVariable("KIT_FIXTURE_DOCUMENT") ?? "protected"}.json";
string document = await File.ReadAllTextAsync(Path.Combine(app.Environment.ContentRootPath, documentName)).ConfigureAwait(false);
app.MapGet("/openapi/v1.json", () => Results.Text(document, "application/json"));
await app.RunAsync().ConfigureAwait(false);

/// <summary>Requires a signed-in caller, as an authorization attribute of an app's own would.</summary>
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
internal sealed class StaffOnlyAttribute : Attribute, IAuthorizationRequirementData
{
    public IEnumerable<IAuthorizationRequirement> GetRequirements() => [new DenyAnonymousAuthorizationRequirement()];
}

/// <summary>
/// Signs in the caller of any bearer token without checking it, as a host whose signature check is off would, so the
/// kit's token checks must fail the site. A caller with no token gets a 401 that names the Bearer scheme.
/// </summary>
[SuppressMessage("Performance", "CA1812:Avoid uninstantiated internal classes", Justification = "The authentication service creates it for its scheme; CA1812 can't see that.")]
internal sealed class AnyBearerToken(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string Name = "Bearer";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        string? header = Request.Headers.Authorization;
        if (header is null || !header.StartsWith($"{Name} ", StringComparison.Ordinal))
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        ClaimsPrincipal user = new(new ClaimsIdentity([new Claim("sub", "fixture-user")], Name));
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(user, Name)));
    }

    protected override Task HandleChallengeAsync(AuthenticationProperties properties)
    {
        Response.Headers.WWWAuthenticate = Name;
        return base.HandleChallengeAsync(properties);
    }
}
