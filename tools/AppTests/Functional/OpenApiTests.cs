using System.Net;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Kit.AppTests.Functional;

/// <summary>
/// The built-in OpenAPI document (API-003) is mapped in Development only: it maps the whole API, so outside Development
/// it isn't published. In Development it answers an anonymous caller, such as a client generator (API-003). A contract
/// test snapshots it, so every change to the API shows in review.
/// </summary>
public sealed class OpenApiTests
{
    private const string Snapshot = "openapi-v1.json";
    private const string Received = "openapi-v1.received.json";
    private static readonly JsonSerializerOptions s_indented = new() { WriteIndented = true };

    [Theory]
    [EachHost("Development", true, HttpStatusCode.OK)]
    [EachHost("Development", false, HttpStatusCode.OK)]
    [EachHost("Production", true, HttpStatusCode.NotFound)]
    public async Task TheDocumentIsServedInDevelopmentOnly(string host, string environment, bool signedIn, HttpStatusCode expected)
    {
        Assert.SkipUnless(AppHost.Named(host).ServesHttpApi, AppHost.NoHttpApi);
        using IAppUnderTest app = AppHost.Named(host).Start(environment);
        using HttpClient client = app.CreateClient(signedIn);

        using HttpResponseMessage response = await client.GetAsync(OpenApiDocument.Path, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(expected);
    }

    // The snapshot is Contract/<host>/openapi-v1.json in the FunctionalTests project. A change writes
    // openapi-v1.received.json beside it (git ignores it): review it, and copy it over the snapshot to accept it.
    [Theory]
    [EachHost]
    public async Task TheDocumentMatchesItsSnapshot(string host)
    {
        Assert.SkipUnless(AppHost.Named(host).ServesHttpApi, AppHost.NoHttpApi);
        JsonNode actual = await OpenApiDocument.ReadAsync(AppHost.Named(host));
        string folder = Path.Combine(ProjectDirectory(), "Contract", host);
        string snapshot = Path.Combine(folder, Snapshot);
        JsonNode? expected = File.Exists(snapshot) ? JsonNode.Parse(await File.ReadAllTextAsync(snapshot, TestContext.Current.CancellationToken)) : null;

        bool matches = JsonNode.DeepEquals(actual, expected);
        if (!matches)
        {
            Directory.CreateDirectory(folder);
            await File.WriteAllTextAsync(Path.Combine(folder, Received), actual.ToJsonString(s_indented), TestContext.Current.CancellationToken);
        }

        matches.Should().BeTrue($"the API contract must match {snapshot}; the current document was written to {Received} beside it, for review");
    }

    // The test project's folder, which tests/Directory.Build.props records at build time: [CallerFilePath] is mapped to
    // /_/ in CI builds.
    private static string ProjectDirectory() =>
        typeof(OpenApiTests).Assembly.GetCustomAttributes<AssemblyMetadataAttribute>()
            .Single(attribute => attribute.Key == "ProjectDirectory").Value!;
}
