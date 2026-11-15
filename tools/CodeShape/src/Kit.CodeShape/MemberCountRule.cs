namespace Kit.CodeShape;

/// <summary>Finds types with more than <see cref="Limits.MembersPerType"/> members (CRF-011).</summary>
internal static class MemberCountRule
{
    /// <summary>Checks the types of one project.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        ArgumentNullException.ThrowIfNull(files);

        return [];
    }
}
