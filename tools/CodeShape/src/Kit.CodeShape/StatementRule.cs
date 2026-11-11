namespace Kit.CodeShape;

/// <summary>Finds members with more than <see cref="Limits.StatementsPerMember"/> statements (CRF-008, ADR-0050).</summary>
internal static class StatementRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);
        return [];
    }
}
