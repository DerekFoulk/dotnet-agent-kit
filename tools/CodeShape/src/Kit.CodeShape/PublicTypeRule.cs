using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds files that declare more than <see cref="Limits.PublicTypesPerFile"/> public types (CRF-011): a
/// class, struct, interface, record, enum or delegate declared outside any other type, which the compiler says is
/// public. A nested type belongs to the type that holds it. A partial type's parts in the file are one type, and a part
/// that doesn't repeat "public" declares a public type when another part, in any file of the project, says so. The
/// finding points at the first type over the limit. A file's exception marker covers it
/// (<see cref="LimitExemption"/>).</summary>
internal static class PublicTypeRule
{
    /// <summary>Checks each of one project's hand-written files, compiled together so a partial type is seen whole.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        CompiledProject project = CompiledProject.Of(files);
        foreach (SyntaxTree tree in project.HandWritten)
        {
            SemanticModel model = project.Compilation.GetSemanticModel(tree);
            CompilationUnitSyntax root = tree.GetCompilationUnitRoot();
            SyntaxToken[] names = [.. TopLevel(root.Members)
                .Select(type => (type.Name, Symbol: model.GetDeclaredSymbol(type.Declaration)))
                .Where(type => type.Symbol is { DeclaredAccessibility: Accessibility.Public })
                .DistinctBy(type => type.Symbol, SymbolEqualityComparer.Default) // a partial type's parts are one type
                .Select(type => type.Name)];
            if (names.Length > Limits.PublicTypesPerFile && !LimitExemption.CoversFile(root))
            {
                yield return Finding.At(
                    tree.FilePath,
                    names[Limits.PublicTypesPerFile].GetLocation(),
                    $"The file declares {names.Length} public types ({string.Join(", ", names.Select(name => name.Text))}); the limit is {Limits.PublicTypesPerFile} (CRF-011).");
            }
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
