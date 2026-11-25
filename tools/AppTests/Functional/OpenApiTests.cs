using System.Net;

namespace Kit.AppTests.Functional;

/// <summary>
/// The built-in OpenAPI document is mapped in Development only (API-003): it maps the whole API, so outside Development
/// it isn't published. In Development it answers an anonymous caller, such as a client generator (API-003).
/// </summary>
public sealed class OpenApiTests
{
    private static readonly Uri s_document = new("/openapi/v1.json", UriKind.Relative);

    [Theory]
    [InlineData("Development", true, HttpStatusCode.OK)]
    [InlineData("Development", false, HttpStatusCode.OK)]
    [InlineData("Production", true, HttpStatusCode.NotFound)]
    public async Task TheDocumentIsServedInDevelopmentOnly(string environment, bool signedIn, HttpStatusCode expected)
    {
        Assert.SkipUnless(AppHost.ServesHttpApi, AppHost.NoHttpApi);
        using IAppUnderTest app = AppHost.Start(environment);
        using HttpClient client = app.CreateClient(signedIn);

        using HttpResponseMessage response = await client.GetAsync(s_document, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(expected);
    }
}
