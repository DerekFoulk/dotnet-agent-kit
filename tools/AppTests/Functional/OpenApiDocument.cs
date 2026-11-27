using System.Text.Json.Nodes;
using Microsoft.Extensions.Hosting;

namespace Kit.AppTests.Functional;

/// <summary>A host's built-in OpenAPI document (API-003), as a client generator reads it in Development.</summary>
internal static class OpenApiDocument
{
    /// <summary>The document's path: the built-in document's default, named v1.</summary>
    public static readonly Uri Path = new("/openapi/v1.json", UriKind.Relative);

    private static readonly string[] s_methods = ["get", "put", "post", "delete", "options", "head", "patch", "trace"];

    /// <summary>Reads the host's document, from the host started in Development.</summary>
    public static async Task<JsonNode> ReadAsync(HostUnderTest host)
    {
        ArgumentNullException.ThrowIfNull(host);
        using IAppUnderTest app = host.Start(Environments.Development);
        using HttpClient client = app.CreateClient(signedIn: true);
        string json = await client.GetStringAsync(Path, TestContext.Current.CancellationToken);
        return JsonNode.Parse(json) ?? throw new InvalidOperationException($"{Path} is empty.");
    }

    /// <summary>
    /// Every operation in the document, with its HTTP method and path. Only operations: a path item can also hold
    /// parameters, a summary or servers.
    /// </summary>
    public static IEnumerable<(string Method, string Path, JsonNode Operation)> Operations(JsonNode document)
    {
        ArgumentNullException.ThrowIfNull(document);
        return (document["paths"]?.AsObject() ?? []).SelectMany(path => path.Value!.AsObject()
            .Where(entry => s_methods.Contains(entry.Key))
            .Select(operation => (operation.Key, path.Key, operation.Value!)));
    }
}
