using System.Diagnostics.CodeAnalysis;

namespace Web;

// Middleware's documented method names are Invoke and InvokeAsync; an async one is InvokeAsync (IDE1006).
[SuppressMessage("Performance", "CA1812:Avoid uninstantiated internal classes", Justification = "UseMiddleware creates it; CA1812 can't see that.")]
internal sealed class TimingMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context) => await next(context);
}
