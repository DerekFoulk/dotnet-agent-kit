using Web;

WebApplication app = WebApplication.CreateBuilder(args).Build();
app.UseMiddleware<TimingMiddleware>();
app.MapRazorPages();
await app.RunAsync();
