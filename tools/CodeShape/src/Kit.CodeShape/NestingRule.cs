using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds members whose statements nest deeper than <see cref="Limits.NestingDepth"/> control-flow
/// statements (CRF-011, ADR-0050).</summary>
internal static class NestingRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        SyntaxTree tree = file.Parse();
        foreach (Member member in Member.Of(tree.GetCompilationUnitRoot()).Where(member => !LimitException.Covers(member.Node)))
        {
            (StatementSyntax Statement, int Depth) deepest = member.Statements
                .Select(statement => (statement, DepthOf(statement, member.Node)))
                .DefaultIfEmpty()
                .MaxBy(pair => pair.Item2);
            if (deepest.Depth > Limits.NestingDepth)
            {
                yield return Finding.At(
                    file.Path,
                    deepest.Statement.GetLocation(),
                    $"{member.Name} nests {deepest.Depth} levels deep; the limit is {Limits.NestingDepth} (CRF-011).");
            }
        }
    }

    // How many control-flow statements enclose this one, inside its member.
    private static int DepthOf(StatementSyntax statement, SyntaxNode member) =>
        statement.Ancestors().TakeWhile(ancestor => ancestor != member).Count(IsLevel);

    // The statements that open a level. An else-if continues its chain: it sits in the else clause of the if before it,
    // and the chain counts once.
    private static bool IsLevel(SyntaxNode node) => node switch
    {
        IfStatementSyntax ifStatement => ifStatement.Parent is not ElseClauseSyntax,
        SwitchStatementSyntax or ForStatementSyntax or CommonForEachStatementSyntax or WhileStatementSyntax or DoStatementSyntax
            or TryStatementSyntax => true,
        _ => false,
    };
}
