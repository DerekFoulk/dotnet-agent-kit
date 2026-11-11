using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;

namespace Bookmarks.Api;

/// <summary>
/// Tells the OpenAPI document's readers that every operation needs a bearer token (SEC-007, SEC-008), after
/// Microsoft's "Use document transformers" sample (learn.microsoft.com/aspnet/core/fundamentals/openapi/customize-openapi).
/// Every operation the document lists needs one: the only anonymous endpoints, health and the document itself, aren't
/// in it. A documented anonymous endpoint would need an operation transformer that skips it, as that page shows.
/// </summary>
internal sealed class BearerSecuritySchemeTransformer : IOpenApiDocumentTransformer
{
    private const string SchemeName = JwtBearerDefaults.AuthenticationScheme;

    public Task TransformAsync(OpenApiDocument document, OpenApiDocumentTransformerContext context, CancellationToken cancellationToken)
    {
        document.Components ??= new OpenApiComponents();
        document.Components.SecuritySchemes = new Dictionary<string, IOpenApiSecurityScheme>
        {
            [SchemeName] = new OpenApiSecurityScheme
            {
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT",
                Description = "An access token from the app's OpenID Connect provider.",
            },
        };

        foreach (OpenApiOperation operation in document.Paths.Values.SelectMany(path => path.Operations?.Values ?? Enumerable.Empty<OpenApiOperation>()))
        {
            operation.Security ??= [];
            operation.Security.Add(new OpenApiSecurityRequirement { [new OpenApiSecuritySchemeReference(SchemeName, document)] = [] });
        }

        return Task.CompletedTask;
    }
}
