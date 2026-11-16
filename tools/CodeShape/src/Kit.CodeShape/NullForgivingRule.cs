using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds a null-forgiving operator (!) with no CRF-001 label, a comment on its line or the line above: the
/// nullable pages ask for it sparingly, and CRF-001 labels each safety net that stays (STY-005).</summary>
internal static class NullForgivingRule
{
    private const string Label = "// CRF-001 safety net:";

    private const string Message = "The null-forgiving operator needs " + Label + " <reason> on its line or the line above (STY-005).";

    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        SyntaxNode root = file.Parse().GetRoot();
        HashSet<int> labelled = [.. root.DescendantTrivia()
            .Where(trivia => trivia.IsKind(SyntaxKind.SingleLineCommentTrivia) && HasReason(trivia.ToString()))
            .Select(trivia => trivia.GetLocation().GetLineSpan().StartLinePosition.Line)];
        return root.DescendantNodes().OfType<PostfixUnaryExpressionSyntax>()
            .Where(node => node.IsKind(SyntaxKind.SuppressNullableWarningExpression))
            .Select(node => node.OperatorToken.GetLocation())
            .Where(location => !IsLabelled(labelled, location.GetLineSpan().StartLinePosition.Line))
            .Select(location => Finding.At(file.Path, location, Message) with { Rule = RuleCodes.Nullable });
    }

    // A label with no reason after it covers nothing, as CRF-001 asks a safety net for its reason.
    private static bool HasReason(string comment) =>
        comment.StartsWith(Label, StringComparison.Ordinal) && !string.IsNullOrWhiteSpace(comment[Label.Length..]);

    private static bool IsLabelled(HashSet<int> labelled, int line) => labelled.Contains(line) || labelled.Contains(line - 1);
}
