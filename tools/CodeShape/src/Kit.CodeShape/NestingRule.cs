using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds members whose statements nest deeper than <see cref="Limits.NestingDepth"/> control-flow
/// statements (CRF-008, ADR-0050).</summary>
internal static class NestingRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        SyntaxTree tree = CSharpSyntaxTree.ParseText(file.Text, path: file.Path);
        foreach (Member member in Member.Of(tree.GetCompilationUnitRoot()))
        {
            (StatementSyntax Statement, int Depth) deepest = member.Statements
                .Select(statement => (statement, DepthOf(statement, member.Node)))
                .DefaultIfEmpty()
                .MaxBy(pair => pair.Item2);
            if (deepest.Depth > Limits.NestingDepth)
            {
                FileLinePositionSpan span = deepest.Statement.GetLocation().GetLineSpan();
                yield return new Finding(
                    file.Path,
                    span.StartLinePosition.Line + 1,
                    span.StartLinePosition.Character + 1,
                    $"{member.Name} nests {deepest.Depth} levels deep; the limit is {Limits.NestingDepth} (CRF-008).");
            }
        }
    }

    // How many control-flow statements enclose this one, inside its member.
    private static int DepthOf(StatementSyntax statement, SyntaxNode member) =>
        statement.Ancestors().TakeWhile(ancestor => ancestor != member).Count(IsLevel);

    private static bool IsLevel(SyntaxNode node) => node is IfStatementSyntax;
}
