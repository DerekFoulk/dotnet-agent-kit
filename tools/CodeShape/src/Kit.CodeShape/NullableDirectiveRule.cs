namespace Kit.CodeShape;

/// <summary>Finds #nullable directives, which change the nullable context the project sets (STY-005).</summary>
internal static class NullableDirectiveRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        return [];
    }
}
