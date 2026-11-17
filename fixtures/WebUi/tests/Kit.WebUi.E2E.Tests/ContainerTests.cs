using DotNet.Testcontainers.Builders;
using DotNet.Testcontainers.Containers;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.WebUi.E2E.Tests;

/// <summary>
/// A test that starts a container of its own, from a project that uses Playwright (GAP-047). The shared CI runs every
/// test project of such a solution inside the Playwright image (ADR-0061), so an app's Testcontainers tests for its
/// database run there too. This proves they can: Testcontainers reaches the runner's Docker through its socket, starts
/// its resource reaper (Ryuk) and the container, and finds the container's port on localhost, which the image runner
/// sets as TESTCONTAINERS_HOST_OVERRIDE.
/// </summary>
public sealed class ContainerTests
{
    // Testcontainers' own sample image, pinned by tag and digest so Docker checks what it pulls: an HTTP server on 8080
    // whose /uuid answers with a new GUID.
    private const string Image = "testcontainers/helloworld:1.3.0@sha256:0583316c97e9ce0b4e2e5029c2c5efb4895e0cfdb412c69474ae38a7ab7815d6";
    private const ushort HttpPort = 8080;
    private const string UuidPath = "uuid";

    [Fact]
    public async Task AContainerTheTestStartsAnswersOnItsMappedPort()
    {
        await using IContainer container = new ContainerBuilder(Image)
            .WithPortBinding(HttpPort, assignRandomHostPort: true)
            .WithWaitStrategy(Wait.ForUnixContainer().UntilHttpRequestIsSucceeded(request => request.ForPort(HttpPort)))
            .Build();
        await container.StartAsync(TestContext.Current.CancellationToken);
        await using ServiceProvider services = new ServiceCollection().AddHttpClient().BuildServiceProvider();
        using HttpClient client = services.GetRequiredService<IHttpClientFactory>().CreateClient();
        Uri uuid = new UriBuilder(Uri.UriSchemeHttp, container.Hostname, container.GetMappedPublicPort(HttpPort), UuidPath).Uri;

        string answer = await client.GetStringAsync(uuid, TestContext.Current.CancellationToken);

        Guid.TryParse(answer, out _).Should().BeTrue($"the container's /uuid answers with a GUID, not \"{answer}\"");
    }
}
