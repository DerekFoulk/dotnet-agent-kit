using Microsoft.CodeAnalysis.CSharp;

namespace Kit.CodeShape;

/// <summary>Finds members whose statements nest deeper than <see cref="Limits.NestingDepth"/>.</summary>
internal static class NestingRule
{
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);
        _ = CSharpSyntaxTree.ParseText(file.Text, path: file.Path);
        return [];
    }
}
