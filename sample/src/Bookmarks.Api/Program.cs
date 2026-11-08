using Bookmarks.Api;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Infrastructure;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);
builder.AddServiceDefaults();

string connectionString = builder.Configuration.GetConnectionString("Bookmarks")
    ?? throw new InvalidOperationException("Set the connection string ConnectionStrings:Bookmarks.");
builder.Services.AddBookmarksInfrastructure(connectionString);
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<BookmarkService>();
builder.Services.AddOpenApi();

// Every error response is Problem Details (RFC 9457): exceptions through the exception handler, and empty 4xx and
// 5xx responses through status code pages (API-002).
builder.Services.AddProblemDetails();

WebApplication app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

// The sample creates its schema on startup; a real app would use migrations.
using (IServiceScope scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<BookmarksDbContext>().Database.EnsureCreated();
}

app.MapDefaultEndpoints();
app.MapOpenApi();
app.MapBookmarks();

app.Run();
