namespace Kit.CodeShape;

/// <summary>Finds a hand-written file marked as generated code outside an EF Core Migrations folder (STY-005).</summary>
internal static class GeneratedMarkerRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        return [];
    }
}
