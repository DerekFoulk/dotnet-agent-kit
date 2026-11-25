using System.Net;

namespace Kit.AppTests.Functional;

/// <summary>
/// The built-in OpenAPI document is mapped in Development only (API-003): it maps the whole API, so outside Development
/// it isn't published. In Development it answers an anonymous caller, such as a client generator (SEC-007).
/// </summary>
public sealed class OpenApiTests
{
    private static readonly Uri s_document = new("/openapi/v1.json", UriKind.Relative);

    [Theory]
    [EachHost("Development", true, HttpStatusCode.OK)]
    [EachHost("Development", false, HttpStatusCode.OK)]
    [EachHost("Production", true, HttpStatusCode.NotFound)]
    public async Task TheDocumentIsServedInDevelopmentOnly(string host, string environment, bool signedIn, HttpStatusCode expected)
    {
        Assert.SkipUnless(AppHost.Named(host).ServesHttpApi, AppHost.NoHttpApi);
        using IAppUnderTest app = AppHost.Named(host).Start(environment);
        using HttpClient client = app.CreateClient(signedIn);

        using HttpResponseMessage response = await client.GetAsync(s_document, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(expected);
    }
}
