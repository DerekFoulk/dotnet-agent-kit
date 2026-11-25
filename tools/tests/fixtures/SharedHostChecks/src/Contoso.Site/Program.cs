// A public website: nobody signs in, so it sets no fallback authorization policy.
WebApplicationBuilder builder = WebApplication.CreateBuilder(args);
WebApplication app = builder.Build();
app.MapGet("/", () => "Welcome");
await app.RunAsync().ConfigureAwait(false);
