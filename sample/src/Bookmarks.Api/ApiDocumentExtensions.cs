namespace Bookmarks.Api;

/// <summary>The API's OpenAPI document (API-003).</summary>
internal static class ApiDocumentExtensions
{
    /// <summary>Describes the API, including that every operation needs a bearer token (SEC-008).</summary>
    public static IServiceCollection AddApiDocument(this IServiceCollection services) =>
        services.AddOpenApi(options => options.AddDocumentTransformer(new BearerSecuritySchemeTransformer()));
}