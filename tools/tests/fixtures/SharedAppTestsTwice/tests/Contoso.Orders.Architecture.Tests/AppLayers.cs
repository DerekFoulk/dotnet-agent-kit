using System.Reflection;
using Contoso.Orders.Domain;
using Contoso.Orders.Infrastructure;

namespace Kit.AppTests.Architecture;

/// <summary>The fixture app's assemblies by layer, with the domain declared in contracts too, which the kit's tests refuse.</summary>
internal static partial class AppLayers
{
    public static partial IReadOnlyList<Assembly> Domain => [typeof(Order).Assembly];

    public static partial IReadOnlyList<Assembly> Contracts => [typeof(Order).Assembly];

    public static partial IReadOnlyList<Assembly> Application => [];

    public static partial IReadOnlyList<Assembly> Infrastructure => [typeof(OrderStore).Assembly];

    public static partial IReadOnlyList<Assembly> Presentation => [];
}
