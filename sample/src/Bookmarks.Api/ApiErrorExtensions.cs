namespace Bookmarks.Api;

/// <summary>
/// Every error response is Problem Details (RFC 9457): exceptions through the exception handler, and empty 4xx and 5xx
/// responses through status code pages (API-002).
/// </summary>
internal static class ApiErrorExtensions
{
    /// <summary>Registers the Problem Details service the exception handler and status code pages write with.</summary>
    public static IServiceCollection AddApiErrors(this IServiceCollection services) => services.AddProblemDetails();

    /// <summary>
    /// Adds the exception handler and status code pages. In Development a binding failure (bad JSON, a query value that
    /// isn't a number) throws BadHttpRequestException; the handler keeps its 400 instead of its default 500. ASP.NET
    /// Core 11 does this by itself.
    /// </summary>
    public static WebApplication UseApiErrors(this WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);
        app.UseExceptionHandler(new ExceptionHandlerOptions
        {
            StatusCodeSelector = exception => exception is BadHttpRequestException badRequest
                ? badRequest.StatusCode
                : StatusCodes.Status500InternalServerError,
        });
        app.UseStatusCodePages();
        return app;
    }
}
