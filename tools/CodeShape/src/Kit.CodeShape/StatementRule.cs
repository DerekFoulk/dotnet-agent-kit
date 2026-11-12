using Microsoft.CodeAnalysis.CSharp;

namespace Kit.CodeShape;

/// <summary>Finds members with more than <see cref="Limits.StatementsPerMember"/> statements (CRF-008, ADR-0050).</summary>
internal static class StatementRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        return Member.Of(file.Parse().GetCompilationUnitRoot())
            .Where(member => member.Statements.Count > Limits.StatementsPerMember && !LimitException.Covers(member.Node))
            .Select(member => Finding.At(
                file.Path,
                member.Location,
                $"{member.Name} has {member.Statements.Count} statements; the limit is {Limits.StatementsPerMember} (CRF-008)."));
    }
}
