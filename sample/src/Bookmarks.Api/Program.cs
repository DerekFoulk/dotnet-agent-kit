using Bookmarks.Api;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Infrastructure;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);
builder.AddServiceDefaults();
// No Server header, a request body cap far under Kestrel's 30 MB default, and a rate limit for each caller (SEC-011).
builder.AddApiHosting();

string connectionString = builder.Configuration.GetConnectionString("Bookmarks")
    ?? throw new InvalidOperationException("Set the connection string ConnectionStrings:Bookmarks.");
builder.Services.AddBookmarksInfrastructure(connectionString);
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<BookmarkService>();
builder.Services.AddApiDocument();

// Every error response is Problem Details (RFC 9457): exceptions through the exception handler, and empty 4xx and
// 5xx responses through status code pages (API-002).
builder.Services.AddApiErrors();

// Validates endpoint parameters from their DataAnnotations and answers a validation problem (API-006).
builder.Services.AddValidation();

// Every endpoint needs a caller signed in with a valid access token, unless it opts out (SEC-007, SEC-008).
builder.Services.AddApiSecurity();

WebApplication app = builder.Build();

// The exception handler and status code pages, first, so every error after them is Problem Details (API-002).
app.UseApiErrors();

// HSTS outside Development (SEC-011). Host filtering, the checklist's first item, WebApplication runs by itself, with
// AllowedHosts from configuration: localhost in appsettings.json, which a deployment sets to its own host names.
app.UseApiHsts();

// After the exception handler and status code pages, so a failed sign-in and the 401 or 403 that follows are Problem
// Details (WebApplication would add them by itself, but ahead of both), and before MapDefaultEndpoints, whose output
// cache must run after them (see its remarks).
// The rate limiter runs after authentication, so a signed-in caller is limited by their user id, and before
// authorization, so a caller with no token or a forged one is limited by IP address before the 401 (review 1).
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();

// The sample creates its schema on startup; a real app would use migrations.
using (IServiceScope scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<BookmarksDbContext>().Database.EnsureCreated();
}

app.MapDefaultEndpoints();
// The OpenAPI document maps the whole API, so it is served in Development only (API-003); the contract test
// snapshots it. It's anonymous, so a developer or a client generator can read it before having a token (SEC-007).
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi().AllowAnonymous();
}

app.MapBookmarks();

app.Run();
