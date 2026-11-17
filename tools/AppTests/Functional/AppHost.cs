using Microsoft.Extensions.DependencyInjection;

namespace Kit.AppTests.Functional;

/// <summary>
/// How the kit's host checks start the app (GAP-037, ADR-0081). This part is the kit's (tools/AppTests in the kit,
/// .kit/tools/AppTests in an app). The app's FunctionalTests project starts its app in its own part, with its test
/// database and sign-in, so the project doesn't build until it says how.
/// </summary>
internal static partial class AppHost
{
    /// <summary>
    /// Starts the app in memory in an environment, with these settings, and these services added after the app's own.
    /// The host turns on ValidateScopes and ValidateOnBuild, in every environment (CRF-013). The caller disposes it.
    /// </summary>
    public static partial IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services);

    /// <summary>Gets the route patterns that allow anonymous callers (SEC-007), as each endpoint's RoutePattern.RawText.</summary>
    public static partial IReadOnlyCollection<string> AnonymousRoutes { get; }

    /// <summary>Starts the app in an environment, as it is.</summary>
    public static IAppUnderTest Start(string environment) => Start(environment, new Dictionary<string, string>(), _ => { });

    /// <summary>Starts the app in an environment with these services added after its own.</summary>
    public static IAppUnderTest Start(string environment, Action<IServiceCollection> services) =>
        Start(environment, new Dictionary<string, string>(), services);

    /// <summary>Starts the app in an environment with these settings.</summary>
    public static IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings) => Start(environment, settings, _ => { });
}

/// <summary>The app, started by <see cref="AppHost"/>.</summary>
internal interface IAppUnderTest : IDisposable
{
    /// <summary>Gets the running app's services.</summary>
    IServiceProvider Services { get; }

    /// <summary>A client of the in-memory app, signed in as a user or anonymous. The caller disposes it.</summary>
    HttpClient CreateClient(bool signedIn);
}
