using Web;

WebApplication app = WebApplication.CreateBuilder(args).Build();
app.UseMiddleware<TimingMiddleware>();
app.UseMiddleware<TracingMiddleware>();
app.MapRazorPages();
await app.RunAsync();
