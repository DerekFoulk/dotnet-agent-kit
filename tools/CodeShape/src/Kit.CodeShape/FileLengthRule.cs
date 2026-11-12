using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.Text;

namespace Kit.CodeShape;

/// <summary>Finds files longer than <see cref="Limits.LinesPerFile"/> lines (CRF-008, ADR-0050).</summary>
internal static class FileLengthRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        TextLineCollection lines = SourceText.From(file.Text).Lines;

        // A final newline ends the last line; the empty "line" after it isn't one (and an empty file has none).
        int count = lines[^1].Span.IsEmpty ? lines.Count - 1 : lines.Count;
        if (count > Limits.LinesPerFile && !LimitException.Covers(CSharpSyntaxTree.ParseText(file.Text).GetRoot()))
        {
            yield return new Finding(
                file.Path,
                Limits.LinesPerFile + 1,
                1,
                $"The file has {count} lines; the limit is {Limits.LinesPerFile} (CRF-008).");
        }
    }
}
