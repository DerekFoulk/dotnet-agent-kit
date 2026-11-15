using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds files that declare more than <see cref="Limits.PublicTypesPerFile"/> public types (CRF-011): a
/// class, struct, interface, record, enum or delegate declared public outside any other type. A nested type belongs
/// to the type that holds it, and a partial type's parts in the file are one type. The finding points at the first
/// type over the limit. A file's exception marker covers it (<see cref="LimitExemption"/>).</summary>
internal static class PublicTypeRule
{
    /// <summary>Checks one file.</summary>
    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        CompilationUnitSyntax root = file.Parse().GetCompilationUnitRoot();
        SyntaxToken[] names = [.. TopLevel(root.Members)
            .Where(type => type.Declaration.Modifiers.Any(SyntaxKind.PublicKeyword))
            .DistinctBy(type => TypeIdentity.Of(type.Declaration), StringComparer.Ordinal) // a partial type's parts are one type
            .Select(type => type.Name)];
        if (names.Length > Limits.PublicTypesPerFile && !LimitExemption.CoversFile(root))
        {
            yield return Finding.At(
                file.Path,
                names[Limits.PublicTypesPerFile].GetLocation(),
                $"The file declares {names.Length} public types ({string.Join(", ", names.Select(name => name.Text))}); the limit is {Limits.PublicTypesPerFile} (CRF-011).");
        }
    }

    // The types declared in a file or a namespace, and in the namespaces inside it, with their names.
    private static IEnumerable<(MemberDeclarationSyntax Declaration, SyntaxToken Name)> TopLevel(SyntaxList<MemberDeclarationSyntax> members) =>
        members.SelectMany(member => member switch
        {
            BaseNamespaceDeclarationSyntax space => TopLevel(space.Members),
            BaseTypeDeclarationSyntax type => [(type, type.Identifier)],
            DelegateDeclarationSyntax type => [(type, type.Identifier)],
            _ => [],
        });
}
