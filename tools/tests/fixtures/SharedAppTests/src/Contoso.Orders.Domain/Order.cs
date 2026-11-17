namespace Contoso.Orders.Domain;

/// <summary>An order: a fixture for the kit's shared architecture tests.</summary>
public sealed class Order
{
    /// <summary>Gets the order's number.</summary>
    public int Number { get; init; }
}
