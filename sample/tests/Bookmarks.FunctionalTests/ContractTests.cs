using System.Text.Json.Nodes;
using Bookmarks.Contracts;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// What the sample's own OpenAPI document says beyond the kit's shared checks of it (tools/AppTests/Functional's
/// OpenApiTests, OpenApiDocumentTests and ContractTypeTests): the create request's limits.
/// </summary>
public sealed class ContractTests : IDisposable
{
    private readonly ApiHost _host = new();

    [Fact]
    public async Task TheDocumentShowsTheCreateRequestsLimits()
    {
        // Review 1: a client generated from the document should know each limit the API enforces (SEC-010). OpenAPI
        // knows [MaxLength] but not the sample's own UriLength, so the URL's limit needs saying.
        JsonNode document = JsonNode.Parse(await _host.Client.GetStringAsync(new Uri("/openapi/v1.json", UriKind.Relative), TestContext.Current.CancellationToken))!;
        JsonNode properties = document["components"]!["schemas"]!["CreateBookmarkRequest"]!["properties"]!;

        (properties["title"]?["maxLength"]?.GetValue<int>()).Should().Be(CreateBookmarkRequest.MaxTitleLength);
        (properties["url"]?["maxLength"]?.GetValue<int>()).Should().Be(CreateBookmarkRequest.MaxUrlLength, "the URL's limit is in the document");
    }

    public void Dispose() => _host.Dispose();
}
