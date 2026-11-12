using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>A member with a body of statements, as the limits measure it: a method, constructor, destructor, operator,
/// accessor, or expression-bodied property or indexer, with any local functions and lambdas inside it; or a file's
/// top-level statements, taken as one.</summary>
/// <param name="Name">The member's name, as findings report it.</param>
/// <param name="Location">Where the member's name is, or the first top-level statement.</param>
/// <param name="Node">The member's declaration, or the file's root for top-level statements.</param>
/// <param name="Statements">Every statement in the member, nested ones included; a block isn't one, only what it holds.</param>
internal sealed record Member(string Name, Location Location, SyntaxNode Node, IReadOnlyList<StatementSyntax> Statements)
{
    /// <summary>The members of a file that hold statements, in the order they appear.</summary>
    public static IEnumerable<Member> Of(CompilationUnitSyntax root)
    {
        ArgumentNullException.ThrowIfNull(root);

        StatementSyntax[] topLevel = [.. root.Members.OfType<GlobalStatementSyntax>()
            .SelectMany(global => StatementsIn(global.Statement))];
        if (topLevel.Length > 0)
        {
            yield return new Member("top-level statements", topLevel[0].GetLocation(), root, topLevel);
        }

        foreach (SyntaxNode node in root.DescendantNodes())
        {
            if (NameOf(node) is var (name, token))
            {
                yield return new Member(name, token.GetLocation(), node, [.. StatementsIn(node)]);
            }
        }
    }

    // A member's declaration isn't a statement, so taking the node itself only matters for a top-level statement.
    private static IEnumerable<StatementSyntax> StatementsIn(SyntaxNode node) =>
        node.DescendantNodesAndSelf()
            .OfType<StatementSyntax>()
            .Where(statement => statement is not BlockSyntax);

    // The name a reader would look for, and the token that carries it.
    private static (string Name, SyntaxToken Token)? NameOf(SyntaxNode node) => node switch
    {
        MethodDeclarationSyntax method => (method.Identifier.Text, method.Identifier),
        ConstructorDeclarationSyntax constructor => (constructor.Identifier.Text, constructor.Identifier),
        DestructorDeclarationSyntax destructor => ($"~{destructor.Identifier.Text}", destructor.Identifier),
        OperatorDeclarationSyntax op => ($"operator {op.OperatorToken.Text}", op.OperatorToken),
        ConversionOperatorDeclarationSyntax conversion =>
            ($"{conversion.ImplicitOrExplicitKeyword.Text} operator {conversion.Type}", conversion.OperatorKeyword),
        PropertyDeclarationSyntax { ExpressionBody: not null } property => (property.Identifier.Text, property.Identifier),
        IndexerDeclarationSyntax { ExpressionBody: not null } indexer => ("this[]", indexer.ThisKeyword),
        AccessorDeclarationSyntax { Parent.Parent: BasePropertyDeclarationSyntax owner } accessor =>
            ($"{OwnerName(owner)}.{accessor.Keyword.Text}", accessor.Keyword),
        _ => null,
    };

    private static string OwnerName(BasePropertyDeclarationSyntax owner) => owner switch
    {
        PropertyDeclarationSyntax property => property.Identifier.Text,
        EventDeclarationSyntax eventDeclaration => eventDeclaration.Identifier.Text,
        _ => "this[]",
    };
}
