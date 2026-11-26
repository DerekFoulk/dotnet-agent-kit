using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Kit.AppTests.Functional;

/// <summary>
/// What the OpenAPI document tells a client generated from it: every error it declares is Problem Details (API-002),
/// and every operation, unless the host lists its route as anonymous, needs a bearer token and may answer 401 or 403
/// (SEC-007, SEC-008).
/// </summary>
public sealed partial class OpenApiDocumentTests
{
    [Theory]
    [EachHost]
    public async Task TheDocumentDescribesEveryErrorAsProblemDetails(string host)
    {
        HostUnderTest described = AppHost.Named(host);
        Assert.SkipUnless(described.ServesHttpApi, AppHost.NoHttpApi);
        JsonNode document = await OpenApiDocument.ReadAsync(described);

        // An error is a 4xx or 5xx status, a 4XX or 5XX range, or the default response, which stands for any other.
        IEnumerable<string> bare = OpenApiDocument.Operations(document)
            .SelectMany(operation => (operation.Operation["responses"]?.AsObject() ?? [])
                .Where(response => response.Key[0] is '4' or '5' || response.Key == "default")
                .Where(response => response.Value?["content"]?["application/problem+json"] is null)
                .Select(response => $"{operation.Method} {operation.Path} {response.Key}"));

        bare.Should().BeEmpty("every error response is Problem Details (API-002)");
    }

    [Theory]
    [EachHost]
    public async Task TheDocumentSaysEveryOperationNeedsABearerTokenAndMayAnswer401Or403(string host)
    {
        HostUnderTest described = AppHost.Named(host);
        Assert.SkipUnless(described.ServesHttpApi, AppHost.NoHttpApi);
        JsonNode document = await OpenApiDocument.ReadAsync(described);
        HashSet<string> anonymous = [.. described.AnonymousRoutes.Select(Template)];

        JsonNode? scheme = document["components"]?["securitySchemes"]?["Bearer"];
        (scheme?["type"]?.GetValue<string>()).Should().Be("http", "the document declares the bearer scheme (SEC-008)");
        (scheme?["scheme"]?.GetValue<string>()).Should().Be("bearer", "the document declares the bearer scheme (SEC-008)");
        IEnumerable<string> unprotected = OpenApiDocument.Operations(document)
            .Where(operation => !anonymous.Contains(Template(operation.Path)) && !IsProtected(operation.Operation))
            .Select(operation => $"{operation.Method} {operation.Path}");

        unprotected.Should().BeEmpty("every operation needs a bearer token, and says it may answer 401 or 403 (SEC-007, SEC-008)");
    }

    private static bool IsProtected(JsonNode operation) =>
        (operation["security"]?.AsArray().Any(requirement => requirement?.AsObject().ContainsKey("Bearer") ?? false) ?? false)
        && operation["responses"]?["401"] is not null
        && operation["responses"]?["403"] is not null;

    // A route's parameters as the document writes them: {id:guid}, {id?}, {id=1}, {*rest} and {**rest} become {id} or
    // {rest}, so an anonymous route matches its operation's path.
    private static string Template(string route) => RouteParameter().Replace(route, "{${name}}");

    [GeneratedRegex(@"\{\**(?<name>[^}:=?]+)[^}]*\}")]
    private static partial Regex RouteParameter();
}
