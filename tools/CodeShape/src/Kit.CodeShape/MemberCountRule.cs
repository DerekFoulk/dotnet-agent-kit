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
                int count = type.Members.Sum(Count) + PositionalProperties(type);
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

    // A field or event declaration declares a member for each name it lists; a nested type isn't a member here.
    private static int Count(MemberDeclarationSyntax member) => member switch
    {
        BaseFieldDeclarationSyntax field => field.Declaration.Variables.Count,
        BaseTypeDeclarationSyntax or DelegateDeclarationSyntax => 0,
        _ => 1,
    };

    // A record's positional parameters are properties the compiler declares for it, unless the record declares the
    // property itself. A class's or struct's primary constructor parameters aren't members.
    private static int PositionalProperties(TypeDeclarationSyntax type)
    {
        if (type is not RecordDeclarationSyntax { ParameterList: { } parameters })
        {
            return 0;
        }

        HashSet<string> declared = [.. type.Members.OfType<PropertyDeclarationSyntax>().Select(property => property.Identifier.Text)];
        return parameters.Parameters.Count(parameter => !declared.Contains(parameter.Identifier.Text));
    }
}
