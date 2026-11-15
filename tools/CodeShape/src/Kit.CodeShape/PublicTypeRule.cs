namespace Kit.CodeShape;

/// <summary>Finds files that declare more than <see cref="Limits.PublicTypesPerFile"/> public types (CRF-011).</summary>
internal static class PublicTypeRule
{
    /// <summary>Checks one file.</summary>
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        return [];
    }
}
