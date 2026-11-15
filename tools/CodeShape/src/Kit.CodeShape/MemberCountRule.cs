using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds types with more than <see cref="Limits.MembersPerType"/> members (CRF-011).</summary>
internal static class MemberCountRule
{
    /// <summary>Checks the types of one project.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        ArgumentNullException.ThrowIfNull(files);

        foreach (SourceFile file in files)
        {
            foreach (TypeDeclarationSyntax type in file.Parse().GetCompilationUnitRoot().DescendantNodes().OfType<TypeDeclarationSyntax>())
            {
                int count = type.Members.Count(member => member is not BaseTypeDeclarationSyntax and not DelegateDeclarationSyntax);
                if (count > Limits.MembersPerType)
                {
                    yield return Finding.At(
                        file.Path,
                        type.Identifier.GetLocation(),
                        $"{type.Identifier.Text} has {count} members; the limit is {Limits.MembersPerType} (CRF-011).");
                }
            }
        }
    }
}
