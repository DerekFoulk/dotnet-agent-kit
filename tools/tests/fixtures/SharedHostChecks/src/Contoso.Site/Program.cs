// A public website with one signed-in endpoint: anyone may read it, so it sets no fallback authorization policy, and
// only its notices endpoint requires authorization. Its OpenAPI document is a fixed file, so the Pester test can serve
// it with and without that endpoint's Bearer requirement (KIT_FIXTURE_DOCUMENT).
WebApplicationBuilder builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthorization();
WebApplication app = builder.Build();
app.UseAuthorization();
app.MapGet("/", () => "Welcome");
app.MapPost("/admin/notices", () => Results.NoContent()).RequireAuthorization();
string documentName = Environment.GetEnvironmentVariable("KIT_FIXTURE_DOCUMENT") == "unprotected" ? "openapi-unprotected.json" : "openapi-protected.json";
string document = await File.ReadAllTextAsync(Path.Combine(app.Environment.ContentRootPath, documentName)).ConfigureAwait(false);
app.MapGet("/openapi/v1.json", () => Results.Text(document, "application/json"));
await app.RunAsync().ConfigureAwait(false);
