using System.Reflection;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The public API contract: the OpenAPI document must match the committed snapshot. A change writes
/// openapi-v1.received.json next to the snapshot; review it and copy it over the snapshot to accept it.
/// </summary>
public sealed class ContractTests : IDisposable
{
    private static readonly JsonSerializerOptions s_indented = new() { WriteIndented = true };
    private readonly ApiHost _host = new();

    [Fact]
    public async Task TheOpenApiDocumentMatchesTheSnapshot()
    {
        string json = await _host.Client.GetStringAsync(new Uri("/openapi/v1.json", UriKind.Relative), TestContext.Current.CancellationToken);
        JsonNode? actual = JsonNode.Parse(json);
        string snapshotPath = Path.Combine(SourceDirectory(), "Contract", "openapi-v1.json");
        JsonNode? expected = File.Exists(snapshotPath) ? JsonNode.Parse(await File.ReadAllTextAsync(snapshotPath, TestContext.Current.CancellationToken)) : null;

        bool matches = JsonNode.DeepEquals(actual, expected);
        if (!matches)
        {
            string receivedPath = Path.Combine(SourceDirectory(), "Contract", "openapi-v1.received.json");
            Directory.CreateDirectory(Path.GetDirectoryName(receivedPath)!);
            await File.WriteAllTextAsync(receivedPath, actual!.ToJsonString(s_indented), TestContext.Current.CancellationToken);
        }

        matches.Should().BeTrue($"the API contract must match {snapshotPath}; the current document was written to openapi-v1.received.json for review");
    }

    [Fact]
    public async Task TheOpenApiDocumentIsNotServedInProduction()
    {
        // API-003: the document maps the whole API, so outside Development it isn't published.
        using ApiHost production = new("Production");

        using HttpResponseMessage response = await production.Client.GetAsync(new Uri("/openapi/v1.json", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(System.Net.HttpStatusCode.NotFound);
    }

    public void Dispose() => _host.Dispose();

    // The project folder, recorded at build time (see the .csproj). [CallerFilePath] is mapped to /_/ in CI builds.
    private static string SourceDirectory() =>
        typeof(ContractTests).Assembly.GetCustomAttributes<AssemblyMetadataAttribute>()
            .Single(attribute => attribute.Key == "ProjectDirectory").Value!;
}
