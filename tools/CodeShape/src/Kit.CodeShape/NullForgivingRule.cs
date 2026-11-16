using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.Text;

namespace Kit.CodeShape;

/// <summary>Finds a null-forgiving operator (!) with no CRF-001 label on its line or the line above: the nullable
/// pages ask for it sparingly, and CRF-001 labels each safety net that stays (STY-005).</summary>
internal static class NullForgivingRule
{
    /// <summary>The label a null-forgiving operator carries, CRF-001's form for a safety net.</summary>
    private const string Label = "// CRF-001 safety net:";

    private const string Message = "The null-forgiving operator needs " + Label + " <reason> on its line or the line above (STY-005).";

    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        SyntaxTree tree = file.Parse();
        TextLineCollection lines = tree.GetText().Lines;
        return tree.GetRoot().DescendantNodes()
            .Where(node => node.IsKind(SyntaxKind.SuppressNullableWarningExpression))
            .Where(node => !IsLabelled(lines, node.GetLocation().GetLineSpan().StartLinePosition.Line))
            .Select(node => Finding.At(file.Path, node.GetLocation(), Message));
    }

    private static bool IsLabelled(TextLineCollection lines, int line) =>
        lines[line].ToString().Contains(Label, StringComparison.Ordinal)
        || (line > 0 && lines[line - 1].ToString().Contains(Label, StringComparison.Ordinal));
}
