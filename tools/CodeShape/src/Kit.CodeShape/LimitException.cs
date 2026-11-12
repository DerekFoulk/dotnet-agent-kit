using System.Text.RegularExpressions;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;

namespace Kit.CodeShape;

/// <summary>The kit's way to exempt one member, type or file from the CRF-008 limits: a single-line comment
/// "// CRF-008 exception: &lt;reason&gt;" right before it (for a file, before its first line). Like
/// [SuppressMessage] with a Justification for an analyzer rule, it carries its reason where it lives, and the
/// reviewer checks the reason holds (craft.md, "Exceptions"; ADR-0050).</summary>
internal static partial class LimitException
{
    /// <summary>Whether the comments right before this node grant it an exception with a reason.</summary>
    public static bool Covers(SyntaxNode node)
    {
        ArgumentNullException.ThrowIfNull(node);

        return node.GetLeadingTrivia()
            .Where(trivia => trivia.IsKind(SyntaxKind.SingleLineCommentTrivia))
            .Any(trivia => Marker().IsMatch(trivia.ToString()));
    }

    [GeneratedRegex(@"^//\s*CRF-008 exception:\s*\S", RegexOptions.CultureInvariant)]
    private static partial Regex Marker();
}
