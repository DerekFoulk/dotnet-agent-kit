using System.Text.RegularExpressions;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>The kit's way to exempt one member, type or file from the CRF-011 limits: a single-line comment
/// "// CRF-011 exception: &lt;reason&gt;". Like [SuppressMessage] with a Justification for an analyzer rule, it
/// carries its reason where it lives, and the reviewer checks the reason holds (craft.md, "Exceptions"; ADR-0050).
/// Where it sits says what it covers:
/// <list type="bullet">
/// <item>a member's or type's is the last comment right before it (before its attributes), with no blank line
/// between; a property's covers its accessors, and a type's covers its cohesion, not its members;</item>
/// <item>a file's is the file's first comment, with a blank line below it, and covers the file's length and its
/// top-level statements.</item>
/// </list>
/// A marker without a reason covers nothing.</summary>
internal static partial class LimitException
{
    /// <summary>Whether a member, or a type's cohesion, has an exception.</summary>
    public static bool Covers(SyntaxNode node)
    {
        ArgumentNullException.ThrowIfNull(node);

        return node switch
        {
            CompilationUnitSyntax root => CoversFile(root),
            AccessorDeclarationSyntax { Parent.Parent: BasePropertyDeclarationSyntax owner } => RightBefore(node) || RightBefore(owner),
            _ => RightBefore(node),
        };
    }

    /// <summary>Whether a file has an exception for its length and its top-level statements.</summary>
    public static bool CoversFile(CompilationUnitSyntax root)
    {
        ArgumentNullException.ThrowIfNull(root);

        SyntaxTriviaList trivia = root.GetLeadingTrivia();
        int first = trivia.IndexOf(trivia.FirstOrDefault(IsComment));
        return first >= 0
            && IsMarker(trivia[first])
            && trivia.Skip(first + 1).TakeWhile(IsSpace).Count(t => t.IsKind(SyntaxKind.EndOfLineTrivia)) >= 2;
    }

    // The last comment before the node is a marker, on the line just above it.
    private static bool RightBefore(SyntaxNode node)
    {
        SyntaxTriviaList trivia = node.GetLeadingTrivia();
        int last = trivia.IndexOf(trivia.LastOrDefault(IsComment));
        return last >= 0
            && IsMarker(trivia[last])
            && trivia.Skip(last + 1).Count(t => t.IsKind(SyntaxKind.EndOfLineTrivia)) <= 1;
    }

    private static bool IsComment(SyntaxTrivia trivia) =>
        trivia.IsKind(SyntaxKind.SingleLineCommentTrivia) || trivia.IsKind(SyntaxKind.MultiLineCommentTrivia);

    private static bool IsSpace(SyntaxTrivia trivia) =>
        trivia.IsKind(SyntaxKind.WhitespaceTrivia) || trivia.IsKind(SyntaxKind.EndOfLineTrivia);

    private static bool IsMarker(SyntaxTrivia trivia) =>
        trivia.IsKind(SyntaxKind.SingleLineCommentTrivia) && Marker().IsMatch(trivia.ToString());

    [GeneratedRegex(@"^//\s*CRF-011 exception:\s*\S", RegexOptions.CultureInvariant)]
    private static partial Regex Marker();
}
