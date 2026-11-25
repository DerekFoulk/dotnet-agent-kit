using System.Reflection;
using Bookmarks.FunctionalTests;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.AppTests.Functional;

/// <summary>The sample's hosts for the kit's host checks (tools/AppTests/Functional): its API, through its own ApiHost.</summary>
internal static partial class AppHost
{
    public static partial IReadOnlyList<HostUnderTest> Hosts => [new BookmarksApi()];

    private sealed class BookmarksApi : HostUnderTest
    {
        public override string Name => "Bookmarks.Api";

        // Probes call the health endpoints without a token, and a developer or client generator reads the Development
        // OpenAPI document before it has one (SEC-007).
        public override IReadOnlyCollection<string> AnonymousRoutes => ["/health", "/alive", "/openapi/{documentName}.json"];

        public override string SignedInRoute => "/bookmarks";

        public override bool ServesHttpApi => true;

        public override IReadOnlyCollection<Assembly> ContractAssemblies => [];

        public override IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services) =>
            new ApiHost(environment, settings, services);
    }
}
