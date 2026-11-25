using System.Reflection;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.AppTests.Functional;

/// <summary>
/// The app's hosts, which the kit's host checks start (GAP-037, ADR-0081). This part is the kit's (tools/AppTests in
/// the kit, .kit/tools/AppTests in an app). The app's FunctionalTests project lists its hosts in its own part, each
/// started with its test database and sign-in, so the project doesn't build until it says how. Every check runs once
/// for each host, through <see cref="EachHostAttribute"/>.
/// </summary>
internal static partial class AppHost
{
    /// <summary>The reason the API's own checks give when they skip.</summary>
    public const string NoHttpApi = "The host serves no HTTP API (HostUnderTest.ServesHttpApi), so the API's checks (API-002, API-003, SEC-008, SEC-013) don't apply.";

    /// <summary>Gets the app's hosts, such as its API and a web UI beside it, each with a name of its own.</summary>
    public static partial IReadOnlyList<HostUnderTest> Hosts { get; }

    /// <summary>The host with this name, as a test's row names it.</summary>
    public static HostUnderTest Named(string name) => Hosts.Single(host => host.Name == name);
}

/// <summary>One of the app's hosts, as its part of <see cref="AppHost"/> starts it.</summary>
internal abstract class HostUnderTest
{
    /// <summary>Gets the host's name, such as its project's, which each test's row shows.</summary>
    public abstract string Name { get; }

    /// <summary>Gets the route patterns that allow anonymous callers (SEC-007), as each endpoint's RoutePattern.RawText.</summary>
    public abstract IReadOnlyCollection<string> AnonymousRoutes { get; }

    /// <summary>
    /// Gets a route a signed-in user may GET, such as one of the host's own endpoints, which the hosting checks send
    /// their requests to (SEC-011): a route with no endpoint would pass a CORS check whatever the host's endpoints allow.
    /// </summary>
    public abstract string SignedInRoute { get; }

    /// <summary>
    /// Gets whether the host serves an HTTP API. The API's own checks skip when it doesn't, as in a Blazor web app with
    /// no API of its own.
    /// </summary>
    public abstract bool ServesHttpApi { get; }

    /// <summary>
    /// Gets the assemblies of the types the host's endpoints may accept and return (SEC-013), such as its Contracts
    /// project's, besides .NET's own. A host that serves no HTTP API has none.
    /// </summary>
    public abstract IReadOnlyCollection<Assembly> ContractAssemblies { get; }

    /// <summary>
    /// Starts the host in memory in an environment, with these settings, and these services added after its own.
    /// The host turns on ValidateScopes and ValidateOnBuild, in every environment (CRF-013). The caller disposes it.
    /// </summary>
    public abstract IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services);

    /// <summary>Starts the host in an environment, as it is.</summary>
    public IAppUnderTest Start(string environment) => Start(environment, new Dictionary<string, string>(), _ => { });

    /// <summary>Starts the host in an environment with these services added after its own.</summary>
    public IAppUnderTest Start(string environment, Action<IServiceCollection> services) =>
        Start(environment, new Dictionary<string, string>(), services);

    /// <summary>Starts the host in an environment with these settings.</summary>
    public IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings) => Start(environment, settings, _ => { });
}

/// <summary>A host, started by <see cref="HostUnderTest"/>.</summary>
internal interface IAppUnderTest : IDisposable
{
    /// <summary>Gets the running host's services.</summary>
    IServiceProvider Services { get; }

    /// <summary>A client of the in-memory host, signed in as a user or anonymous. The caller disposes it.</summary>
    HttpClient CreateClient(bool signedIn);
}
