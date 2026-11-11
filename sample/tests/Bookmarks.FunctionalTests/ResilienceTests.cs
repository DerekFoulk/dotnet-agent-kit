using System.Net;
using Microsoft.Extensions.DependencyInjection;

namespace Bookmarks.FunctionalTests;

/// <summary>The resilience every HttpClient gets from the service defaults (OPS-003, ADR-0037).</summary>
public sealed class ResilienceTests : IDisposable
{
    private readonly ApiHost _host = new();

    [Fact]
    public void EveryHttpClientGetsTheStandardResilienceHandler()
    {
        // Timeouts, retries with backoff and a circuit breaker on every outbound call, by default (OPS-003).
        IHttpMessageHandlerFactory? factory = _host.Services.GetService<IHttpMessageHandlerFactory>();
        factory.Should().NotBeNull("the service defaults set up IHttpClientFactory with resilience");
        using HttpMessageHandler handler = factory!.CreateHandler("any-client");
        List<string> chain = [];
        for (HttpMessageHandler? current = handler; current is not null; current = (current as DelegatingHandler)?.InnerHandler)
        {
            chain.Add(current.GetType().Name);
        }

        chain.Should().Contain("ResilienceHandler");
    }

    [Fact]
    public async Task AFailedPostIsNotRetriedSoItCanNotBeSentTwice()
    {
        // Review 1 of PR 21: the standard handler retries every method by default, so a payment POST could be
        // sent twice. The defaults retry only safe methods.
        using FailingHandler server = new();
        using ApiHost host = new(services: services => services.AddHttpClient("payments").ConfigurePrimaryHttpMessageHandler(() => server));
        using HttpClient client = host.Services.GetRequiredService<IHttpClientFactory>().CreateClient("payments");

        using HttpResponseMessage response = await client.PostAsync(new Uri("https://payments.example/charge"), null, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        server.Calls.Should().Be(1, "a POST isn't safe to repeat");
    }

    public void Dispose() => _host.Dispose();

    /// <summary>A server that always answers 503, counting the calls it gets.</summary>
    private sealed class FailingHandler : HttpMessageHandler
    {
        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable));
        }
    }
}
