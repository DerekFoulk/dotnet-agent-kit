namespace Contoso.Orders.Domain;

/// <summary>A domain type that reads infrastructure and knows ADO.NET: a fixture for the kit's shared architecture tests.</summary>
public static class Leak
{
    /// <summary>Gets the store's name.</summary>
    public static string StoreName => Infrastructure.OrderStore.Name;

    /// <summary>Gets ADO.NET's connection type.</summary>
    public static Type Connection => typeof(System.Data.Common.DbConnection);
}
