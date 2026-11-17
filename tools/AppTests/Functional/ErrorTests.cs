using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Kit.AppTests.Functional;

/// <summary>
/// Every error response is Problem Details (API-002): the app's own errors, which its own tests check, and these two,
/// which every app answers the same way: a route that doesn't exist, and an unhandled exception, whose 500 carries
/// neither its message nor its stack outside Development.
/// </summary>
public sealed class ErrorTests
{
    private const string ProblemJson = "application/problem+json";

    [Fact]
    public async Task ARouteThatDoesNotExistIsANotFoundProblem()
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production);
        using HttpClient client = app.CreateClient(signedIn: true);

        using HttpResponseMessage response = await client.GetAsync(new Uri("/kit-no-such-route", UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        (response.Content.Headers.ContentType?.MediaType).Should().Be(ProblemJson);
    }

    [Fact]
    public async Task AnUnhandledErrorIsAProblemWithoutItsDetailsInProduction()
    {
        using IAppUnderTest app = AppHost.Start(Environments.Production, services => services.AddSingleton<IStartupFilter>(new ThrowingRoute()));
        using HttpClient client = app.CreateClient(signedIn: true);

        using HttpResponseMessage response = await client.GetAsync(new Uri(ThrowingRoute.Path, UriKind.Relative), TestContext.Current.CancellationToken);

        response.StatusCode.Should().Be(HttpStatusCode.InternalServerError);
        (response.Content.Headers.ContentType?.MediaType).Should().Be(ProblemJson);
        (await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken))
            .Should().NotContain(ThrowingRoute.Secret).And.NotContain(nameof(ThrowingRoute));
    }

    /// <summary>
    /// Adds a branch after the app's own pipeline that throws, so the exception passes through the app's exception
    /// handler as one thrown by an endpoint would. A request with no endpoint reaches it once the app's pipeline has
    /// passed it on.
    /// </summary>
    private sealed class ThrowingRoute : IStartupFilter
    {
        public const string Path = "/kit-unhandled-error";
        public const string Secret = "kit-secret-detail";

        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            next(app);
            app.Map(Path, branch => branch.Run(_ => throw new InvalidOperationException(Secret)));
        };
    }
}
