namespace Contoso.Orders.Api;

/// <summary>Routes under a name the endpoint check doesn't look for: a fixture for the kit's shared architecture tests.</summary>
public static class OrderRoutes
{
    /// <summary>Gets the routes' prefix.</summary>
    public static string Prefix => "/orders";
}
