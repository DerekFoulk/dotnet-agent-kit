using System.Reflection;
using Contoso.Orders.Api;
using Contoso.Orders.Domain;
using Contoso.Orders.Infrastructure;

namespace Kit.AppTests.Architecture;

/// <summary>The broken app's assemblies by layer: the application project is left out on purpose.</summary>
internal static partial class AppLayers
{
    public static partial IReadOnlyList<Assembly> Domain => [typeof(Order).Assembly];

    public static partial IReadOnlyList<Assembly> Contracts => [];

    public static partial IReadOnlyList<Assembly> Application => [];

    public static partial IReadOnlyList<Assembly> Infrastructure => [typeof(OrderStore).Assembly];

    public static partial IReadOnlyList<Assembly> Presentation => [typeof(OrderRoutes).Assembly];
}
