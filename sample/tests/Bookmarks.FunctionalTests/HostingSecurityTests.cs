using System.Collections.Concurrent;
using System.Net;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// Microsoft's Kestrel production security checklist, as the sample applies it (SEC-011): host filtering, HSTS, rate
/// limiting, no CORS unless an origin is named, a request body cap well under the 30 MB default, and no Server header.
/// </summary>
public sealed class HostingSecurityTests : IDisposable
{
    private readonly ApiHost _host = new("Production");

    public void Dispose() => _host.Dispose();

    [Fact]
    public async Task ARequestForAnotherHostIsRejectedInProduction()
    {
        using HttpRequestMessage request = new(HttpMethod.Get, "/bookmarks");
        request.Headers.Host = "attacker.example";

        using HttpResponseMessage response = await _host.Client.SendAsync(request, TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task AnHttpsResponseCarriesHstsInProduction()
    {
        // UseHsts leaves localhost out, so the request names the host a deployment would allow.
        using ApiHost host = new("Production", new Dictionary<string, string> { ["AllowedHosts"] = "bookmarks.example" });
        using HttpRequestMessage request = new(HttpMethod.Get, new Uri("https://bookmarks.example/bookmarks"));

        using HttpResponseMessage response = await host.Client.SendAsync(request, TestContext.Current.CancellationToken);

        response.Headers.Contains("Strict-Transport-Security").Should().BeTrue();
    }

    [Fact]
    public async Task AFloodFromOneCallerIsAnsweredWithTooManyRequests()
    {
        // A burst of 5 and 1 more a second: 20 requests at once go over it, however slow the machine.
        using ApiHost host = new("Production", new Dictionary<string, string>
        {
            ["RateLimiting:BurstLimit"] = "5",
            ["RateLimiting:RequestsPerSecond"] = "1",
        });
        List<HttpStatusCode> statuses = [];
        for (int i = 0; i < 20; i++)
        {
            using HttpResponseMessage response = await host.Client.GetAsync(new Uri("/bookmarks?limit=1", UriKind.Relative), TestContext.Current.CancellationToken);
            statuses.Add(response.StatusCode);
        }

        statuses.Should().Contain(HttpStatusCode.TooManyRequests);
    }

    // Review 1: the limiter ran after authorization, so a caller with no token, or a forged one, was never limited.
    [Theory]
    [InlineData(null)]
    [InlineData("not-a-token")]
    public async Task AFloodWithoutAValidTokenIsAnsweredWithTooManyRequests(string? token)
    {
        using ApiHost host = SlowLimit();
        using HttpClient caller = host.CreateClient(token);

        List<HttpStatusCode> statuses = await Flood(caller, "/bookmarks?limit=1");

        statuses.Should().Contain(HttpStatusCode.TooManyRequests);
    }

    [Fact]
    public async Task ARejectedRequestSaysWhenToRetryInProblemDetails()
    {
        using ApiHost host = SlowLimit();

        using HttpResponseMessage rejected = await FirstRejected(host.Client, "/bookmarks?limit=1");

        rejected.Headers.RetryAfter.Should().NotBeNull();
        rejected.Content.Headers.ContentType?.MediaType.Should().Be("application/problem+json");
    }

    // A limit of 0 or less would make every request fail; options validation stops the app at startup instead (OPS-006).
    [Theory]
    [InlineData("RateLimiting:BurstLimit", "BurstLimit")]
    [InlineData("RateLimiting:RequestsPerSecond", "RequestsPerSecond")]
    public void ARateLimitBelowOneStopsTheAppFromStarting(string setting, string property)
    {
        using ExceptionLog log = new();
        Action start = () =>
        {
            using ApiHost host = new("Production", new Dictionary<string, string> { [setting] = "0" }, services => services.AddSingleton<ILoggerProvider>(log));
        };

        // Which exception WebApplicationFactory throws when the host fails to start varies from run to run (on CI it was
        // once an ObjectDisposedException); the host logs the real cause either way, so the test reads it from the log.
        start.Should().Throw<Exception>();
        log.Exceptions.OfType<OptionsValidationException>().Should().Contain(exception => exception.Message.Contains(property, StringComparison.Ordinal));
    }

    // A platform's liveness probes come from one address; limiting them would get a healthy app restarted.
    [Theory]
    [InlineData("/alive")]
    [InlineData("/health")]
    public async Task TheHealthProbesAreNotRateLimited(string path)
    {
        using ApiHost host = SlowLimit();
        using HttpClient probe = host.CreateClient(token: null);

        List<HttpStatusCode> statuses = await Flood(probe, path);

        statuses.Should().NotContain(HttpStatusCode.TooManyRequests);
    }

    [Fact]
    public async Task ACrossOriginPreflightGetsNoPermission()
    {
        using HttpRequestMessage preflight = new(HttpMethod.Options, "/bookmarks");
        preflight.Headers.Add("Origin", "https://attacker.example");
        preflight.Headers.Add("Access-Control-Request-Method", "POST");

        using HttpResponseMessage response = await _host.Client.SendAsync(preflight, TestContext.Current.CancellationToken);

        response.Headers.Contains("Access-Control-Allow-Origin").Should().BeFalse();
    }

    [Fact]
    public void KestrelSendsNoServerHeaderAndCapsTheRequestBody()
    {
        KestrelServerOptions kestrel = _host.Services.GetRequiredService<IOptions<KestrelServerOptions>>().Value;

        kestrel.AddServerHeader.Should().BeFalse();
        kestrel.Limits.MaxRequestBodySize.Should().BeLessThanOrEqualTo(1024 * 1024);
    }

    // A burst of 5 and 1 more a second: 20 requests at once go over it, however slow the machine.
    private static ApiHost SlowLimit() => new("Production", new Dictionary<string, string>
    {
        ["RateLimiting:BurstLimit"] = "5",
        ["RateLimiting:RequestsPerSecond"] = "1",
    });

    private static async Task<List<HttpStatusCode>> Flood(HttpClient client, string path)
    {
        List<HttpStatusCode> statuses = [];
        for (int i = 0; i < 20; i++)
        {
            using HttpResponseMessage response = await client.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);
            statuses.Add(response.StatusCode);
        }

        return statuses;
    }

    private static async Task<HttpResponseMessage> FirstRejected(HttpClient client, string path)
    {
        for (int i = 0; i < 20; i++)
        {
            HttpResponseMessage response = await client.GetAsync(new Uri(path, UriKind.Relative), TestContext.Current.CancellationToken);
            if (response.StatusCode == HttpStatusCode.TooManyRequests)
            {
                return response;
            }

            response.Dispose();
        }

        throw new InvalidOperationException("No request was rejected.");
    }

    /// <summary>Keeps every exception the app logs, so a test can read why the host failed to start.</summary>
    private sealed class ExceptionLog : ILoggerProvider
    {
        private readonly ConcurrentQueue<Exception> _exceptions = new();

        public IEnumerable<Exception> Exceptions => _exceptions;

        public ILogger CreateLogger(string categoryName) => new Logger(_exceptions);

        public void Dispose()
        {
        }

        private sealed class Logger(ConcurrentQueue<Exception> exceptions) : ILogger
        {
            public IDisposable? BeginScope<TState>(TState state)
                where TState : notnull => null;

            public bool IsEnabled(LogLevel logLevel) => true;

            public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
            {
                if (exception is not null)
                {
                    exceptions.Enqueue(exception);
                }
            }
        }
    }
}
