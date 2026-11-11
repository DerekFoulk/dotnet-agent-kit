using Bookmarks.Contracts;

namespace Bookmarks.Api;

/// <summary>The API's OpenAPI document (API-003).</summary>
internal static class ApiDocumentExtensions
{
    /// <summary>
    /// Describes the API, including that every operation needs a bearer token (SEC-008) and each limit on a request
    /// (SEC-010): OpenAPI reads [MaxLength] by itself, but not the sample's own UriLength, which a schema transformer
    /// (learn.microsoft.com/aspnet/core/fundamentals/openapi/customize-openapi#use-schema-transformers) adds.
    /// </summary>
    public static IServiceCollection AddApiDocument(this IServiceCollection services) =>
        services.AddOpenApi(options =>
        {
            options.AddDocumentTransformer(new BearerSecuritySchemeTransformer());
            options.AddSchemaTransformer((schema, context, cancellationToken) =>
            {
                if (context.JsonPropertyInfo?.AttributeProvider?.GetCustomAttributes(typeof(UriLengthAttribute), inherit: false)
                    is [UriLengthAttribute length, ..])
                {
                    schema.MaxLength = length.MaximumLength;
                }

                return Task.CompletedTask;
            });
        });
}
