using Bookmarks.FunctionalTests;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.AppTests.Functional;

/// <summary>How the kit's host checks (tools/AppTests/Functional) start the sample: through its own ApiHost.</summary>
internal static partial class AppHost
{
    public static partial IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services) =>
        new ApiHost(environment, settings, services);

    // Probes call the health endpoints without a token, and a developer or client generator reads the Development
    // OpenAPI document before it has one (SEC-007).
    public static partial IReadOnlyCollection<string> AnonymousRoutes => ["/health", "/alive", "/openapi/{documentName}.json"];
}
