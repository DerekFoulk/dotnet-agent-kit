using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>A member with a body of statements, as the limits measure it: a method, constructor, destructor, operator
/// or accessor, with any local functions and lambdas inside it; or a file's top-level statements, taken as one.</summary>
/// <param name="Name">The member's name, as findings report it.</param>
/// <param name="Node">The member's declaration, or the file's root for top-level statements.</param>
/// <param name="Statements">Every statement in the member, nested ones included; a block isnt one, only what it holds.</param>
internal sealed record Member(string Name, SyntaxNode Node, IReadOnlyList<StatementSyntax> Statements)
{
    /// <summary>The members of a file that hold statements, in the order they appear.</summary>
    public static IEnumerable<Member> Of(CompilationUnitSyntax root)
    {
        ArgumentNullException.ThrowIfNull(root);

        StatementSyntax[] topLevel = [.. root.Members.OfType<GlobalStatementSyntax>()
            .SelectMany(global => StatementsIn(global.Statement, includeSelf: true))];
        if (topLevel.Length > 0)
        {
            yield return new Member("top-level statements", root, topLevel);
        }

        foreach (SyntaxNode node in root.DescendantNodes())
        {
            if (NameOf(node) is { } name)
            {
                yield return new Member(name, node, [.. StatementsIn(node, includeSelf: false)]);
            }
        }
    }

    private static IEnumerable<StatementSyntax> StatementsIn(SyntaxNode node, bool includeSelf) =>
        (includeSelf ? node.DescendantNodesAndSelf() : node.DescendantNodes()).OfType<StatementSyntax>().Where(statement => statement is not BlockSyntax);

    private static string? NameOf(SyntaxNode node) => node switch
    {
        MethodDeclarationSyntax method => method.Identifier.Text,
        _ => null,
    };
}
