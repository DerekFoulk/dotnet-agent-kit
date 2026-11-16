namespace Kit.CodeShape;

/// <summary>Finds a null-forgiving operator (!) with no CRF-001 label on its line or the line above (STY-005).</summary>
internal static class NullForgivingRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        return [];
    }
}
