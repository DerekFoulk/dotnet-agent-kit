namespace VisibleStaticReadonly;

// STY-007: a static readonly field that isn't private is named in PascalCase, as a public one is in the Framework Design
// Guidelines, so CA1707, which checks internal APIs here (STY-009), finds no underscore; a private one keeps s_.

/// <summary>Where a catalog is read from.</summary>
public class CatalogSource
{
    /// <summary>The public source.</summary>
    public static readonly Uri PublicSource = new("https://example.com/public");

    /// <summary>The protected source.</summary>
    protected static readonly Uri ProtectedSource = new("https://example.com/protected");

    /// <summary>The protected internal source.</summary>
    protected internal static readonly Uri ProtectedInternalSource = new("https://example.com/protected-internal");

    internal static readonly Uri InternalSource = new("https://example.com/internal");

    private protected static readonly Uri PrivateProtectedSource = new("https://example.com/private-protected");

    private static readonly Uri s_privateSource = new("https://example.com/private");

    /// <summary>Picks a source.</summary>
    /// <param name="index">Which source, from 0 to 4; any other value picks the private one.</param>
    /// <returns>The source.</returns>
    public virtual Uri Pick(int index) => index switch
    {
        0 => PublicSource,
        1 => ProtectedSource,
        2 => ProtectedInternalSource,
        3 => InternalSource,
        4 => PrivateProtectedSource,
        _ => s_privateSource,
    };
}
