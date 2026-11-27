// A public website with a few signed-in endpoints: anyone may read it, so it sets no fallback authorization policy.
// Only the admin group requires authorization, and in it the status endpoint allows anonymous callers again. The group
// is mapped without a leading slash, and its feed endpoint answers every method. Its OpenAPI document is a fixed file,
// so the Pester test can serve one where the signed-in operations require the Bearer scheme, one where they don't, and
// one that describes only the public operations (KIT_FIXTURE_DOCUMENT).
WebApplicationBuilder builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthorization();
WebApplication app = builder.Build();
app.UseAuthorization();
app.MapGet("/", () => "Welcome");
RouteGroupBuilder admin = app.MapGroup("admin").RequireAuthorization();
admin.MapPost("notices", () => Results.NoContent());
admin.Map("feed", () => "Feed");
admin.MapGet("status", () => "Open").AllowAnonymous();
string documentName = $"openapi-{Environment.GetEnvironmentVariable("KIT_FIXTURE_DOCUMENT") ?? "protected"}.json";
string document = await File.ReadAllTextAsync(Path.Combine(app.Environment.ContentRootPath, documentName)).ConfigureAwait(false);
app.MapGet("/openapi/v1.json", () => Results.Text(document, "application/json"));
await app.RunAsync().ConfigureAwait(false);
