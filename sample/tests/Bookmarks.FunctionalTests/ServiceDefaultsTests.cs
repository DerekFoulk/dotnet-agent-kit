using System.Net;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The service defaults every ASP.NET Core app gets (OPS-001 to OPS-003, ADR-0037): health endpoints, OpenTelemetry
/// and HTTP resilience, from the Bookmarks.ServiceDefaults project.
/// </summary>
public sealed class ServiceDefaultsTests : IDisposable
{
    private readonly ApiHost _host = new();

    [Fact]
    public async Task AliveAnswersHealthyWhenTheAppIsRunning()
    {
        using HttpResponseMessage response = await _host.Client.GetAsync(new Uri("/alive", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken)).Should().Be("Healthy");
    }

    public void Dispose() => _host.Dispose();
}
