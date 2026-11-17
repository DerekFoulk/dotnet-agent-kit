using System.Reflection;
using Contoso.Orders.Domain;
using Contoso.Orders.Infrastructure;

namespace Kit.AppTests.Architecture;

/// <summary>The fixture app's assemblies, layer by layer, for the kit's architecture tests.</summary>
internal static partial class AppLayers
{
    public static partial IReadOnlyList<Assembly> Domain => [typeof(Order).Assembly];

    public static partial IReadOnlyList<Assembly> Contracts => [];

    public static partial IReadOnlyList<Assembly> Application => [];

    public static partial IReadOnlyList<Assembly> Infrastructure => [typeof(OrderStore).Assembly];

    public static partial IReadOnlyList<Assembly> Presentation => [];
}
