using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Hosting;

namespace Kit.AppTests.Functional;

/// <summary>
/// What the OpenAPI document tells a client generated from it: every error it declares is Problem Details (API-002),
/// and every protected operation needs a bearer token and may answer 401 or 403 (SEC-008). Which operations are
/// protected follows SEC-017: in a host whose endpoints mostly require sign-in, every operation the host doesn't list
/// as anonymous; in a mostly public host, the operations whose endpoints require authorization.
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
    public async Task TheDocumentSaysEveryProtectedOperationNeedsABearerTokenAndMayAnswer401Or403(string host)
    {
        HostUnderTest described = AppHost.Named(host);
        Assert.SkipUnless(described.ServesHttpApi, AppHost.NoHttpApi);
        JsonNode document = await OpenApiDocument.ReadAsync(described);
        Func<string, string, bool> mustBeProtected = ProtectedOperations(described);

        List<(string Method, string Path, JsonNode Operation)> required = [.. OpenApiDocument.Operations(document)
            .Where(operation => mustBeProtected(operation.Method, operation.Path))];
        JsonNode? scheme = document["components"]?["securitySchemes"]?["Bearer"];
        bool declaresBearer = scheme?["type"]?.GetValue<string>() == "http" && scheme["scheme"]?.GetValue<string>() == "bearer";
        IEnumerable<string> unprotected = required
            .Where(operation => !IsProtected(operation.Operation))
            .Select(operation => $"{operation.Method} {operation.Path}");

        // A mostly public host with no protected operation needn't declare the scheme at all.
        (declaresBearer || (required.Count == 0 && !described.MostEndpointsRequireSignIn)).Should().BeTrue("the document declares the bearer scheme (SEC-008)");
        unprotected.Should().BeEmpty("every protected operation needs a bearer token, and says it may answer 401 or 403 (SEC-008, SEC-017)");
    }

    // Whether an operation (its method and the document's path) must be protected. SEC-017's fallback policy protects
    // every endpoint without authorization metadata, so in a host whose endpoints mostly require sign-in it's every
    // operation not on an anonymous route. In a mostly public host only an endpoint's own authorization metadata
    // protects it, so it's the operations whose endpoints carry it and don't allow anonymous callers.
    private static Func<string, string, bool> ProtectedOperations(HostUnderTest host)
    {
        if (host.MostEndpointsRequireSignIn)
        {
            HashSet<string> anonymous = [.. host.AnonymousRoutes.Select(Route)];
            return (_, path) => !anonymous.Contains(Route(path));
        }

        using IAppUnderTest app = host.Start(Environments.Development);
        IReadOnlyList<RouteEndpoint> authorized = EndpointAuthorization.Protected(app.Services);

        // An endpoint without HTTP method metadata answers every method.
        HashSet<string> keys = [.. authorized.SelectMany(endpoint =>
            (endpoint.Metadata.GetMetadata<IHttpMethodMetadata>()?.HttpMethods ?? ["*"])
                .Select(method => Key(method, endpoint.RoutePattern.RawText ?? string.Empty)))];
        return (method, path) => keys.Contains(Key(method, path)) || keys.Contains(Key("*", path));
    }

    // An operation's method and path, as both the document and an endpoint can name it.
    private static string Key(string method, string route) => $"{method.ToUpperInvariant()} {Route(route)}";

    // A route as the document writes its path: with a leading slash, which an endpoint's RawText (and so an entry in
    // AnonymousRoutes) lacks when its group is mapped without one, and with its parameters as Template writes them.
    private static string Route(string route) => Template("/" + route.TrimStart('/'));

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
