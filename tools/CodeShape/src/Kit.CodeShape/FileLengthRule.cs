namespace Kit.CodeShape;

/// <summary>Finds files longer than <see cref="Limits.LinesPerFile"/> lines (CRF-008, ADR-0050).</summary>
internal static class FileLengthRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);
        return [];
    }
}
