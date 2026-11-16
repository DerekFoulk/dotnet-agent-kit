using System.Diagnostics.CodeAnalysis;

namespace Web;

// Middleware's documented method names are Invoke and InvokeAsync, both allowed (STY-007's advisory part).
[SuppressMessage("Performance", "CA1812:Avoid uninstantiated internal classes", Justification = "UseMiddleware creates it; CA1812 can't see that.")]
internal sealed class TimingMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context) => await next(context);
}

// An async Invoke, which VSTHRD200 would flag and STY-007 exempts, as the middleware page documents the name.
[SuppressMessage("Performance", "CA1812:Avoid uninstantiated internal classes", Justification = "UseMiddleware creates it; CA1812 can't see that.")]
internal sealed class TracingMiddleware(RequestDelegate next)
{
    public async Task Invoke(HttpContext context) => await next(context);
}
