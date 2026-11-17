namespace Contoso.Orders.Infrastructure;

/// <summary>Where orders are kept: a fixture for the kit's shared architecture tests.</summary>
public static class OrderStore
{
    /// <summary>Gets the store's name. A property, not a constant, so code that reads it references this assembly.</summary>
    public static string Name => "orders";
}
