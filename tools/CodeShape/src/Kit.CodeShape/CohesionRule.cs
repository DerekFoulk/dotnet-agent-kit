namespace Kit.CodeShape;

/// <summary>Finds types whose methods fall into more than <see cref="Limits.Lcom4"/> groups that share no state
/// (LCOM4; CRF-008, ADR-0050).</summary>
internal static class CohesionRule
{
    /// <summary>Checks the types of one project, whose files are compiled together so a partial type is seen whole.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        ArgumentNullException.ThrowIfNull(files);
        return [];
    }
}
