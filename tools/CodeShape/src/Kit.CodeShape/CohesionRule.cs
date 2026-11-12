using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds types whose methods fall into more than <see cref="Limits.Lcom4"/> groups that share no state
/// (LCOM4; CRF-008, ADR-0050).</summary>
internal static class CohesionRule
{
    // The running .NET's own assemblies, a documented runtime property. They let the compiler bind the code's own
    // members; a project's packages aren't needed for that, and types from them stay unresolved, which LCOM4 ignores.
    private static readonly Lazy<MetadataReference[]> s_runtime = new(() =>
        [.. ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!)
            .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries)
            .Select(path => MetadataReference.CreateFromFile(path))]);

    /// <summary>Checks the types of one project, whose files are compiled together so a partial type is seen whole.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        ArgumentNullException.ThrowIfNull(files);

        SyntaxTree[] trees = [.. files.Select(file => CSharpSyntaxTree.ParseText(file.Text, path: file.Path))];
        CSharpCompilation compilation = CSharpCompilation.Create("CodeShape", trees, s_runtime.Value);
        foreach (SyntaxTree tree in trees)
        {
            SemanticModel model = compilation.GetSemanticModel(tree);
            foreach (TypeDeclarationSyntax declaration in tree.GetRoot().DescendantNodes().OfType<TypeDeclarationSyntax>())
            {
                if (model.GetDeclaredSymbol(declaration) is not { } type || IsExempt(type))
                {
                    continue;
                }

                IReadOnlyList<IReadOnlyList<ISymbol>> groups = Groups(type, compilation);
                if (groups.Count > Limits.Lcom4)
                {
                    string listed = string.Join(", ", groups.Select(group => $"[{string.Join(", ", group.Select(method => method.Name))}]"));
                    yield return Finding.At(
                        tree.FilePath,
                        declaration.Identifier.GetLocation(),
                        $"{type.Name}'s methods form {groups.Count} groups that share no state (LCOM4 {groups.Count}; the limit is {Limits.Lcom4}): {listed} (CRF-008).");
                }
            }
        }
    }

    // A partial type is exempt when any of its declarations carries the exception.
    private static bool IsExempt(INamedTypeSymbol type) =>
        type.DeclaringSyntaxReferences.Any(reference => LimitException.Covers(reference.GetSyntax()));

    // The type's methods that use its instance state, grouped by what they share, in declaration order.
    private static IReadOnlyList<IReadOnlyList<ISymbol>> Groups(INamedTypeSymbol type, Compilation compilation)
    {
        DisjointSets sets = new();
        List<ISymbol> methods = [];
        foreach (TypeDeclarationSyntax declaration in type.DeclaringSyntaxReferences.Select(reference => reference.GetSyntax()).OfType<TypeDeclarationSyntax>())
        {
            SemanticModel model = compilation.GetSemanticModel(declaration.SyntaxTree);
            foreach (MethodDeclarationSyntax method in declaration.Members.OfType<MethodDeclarationSyntax>())
            {
                if (model.GetDeclaredSymbol(method) is not { IsStatic: false } symbol)
                {
                    continue;
                }

                ISymbol[] uses = [.. InstanceMembersUsed(method, type, model)];
                if (uses.Length == 0)
                {
                    continue;
                }

                methods.Add(symbol);
                foreach (ISymbol used in uses)
                {
                    sets.Join(symbol, used);
                }
            }
        }

        return [.. methods.GroupBy(sets.Root, SymbolEqualityComparer.Default).Select(group => (IReadOnlyList<ISymbol>)[.. group])];
    }

    // The type's own instance members that a body names.
    private static IEnumerable<ISymbol> InstanceMembersUsed(SyntaxNode body, INamedTypeSymbol type, SemanticModel model) =>
        body.DescendantNodes().OfType<SimpleNameSyntax>()
            .Select(name => model.GetSymbolInfo(name).Symbol)
            .OfType<ISymbol>()
            .Where(symbol => !symbol.IsStatic && SymbolEqualityComparer.Default.Equals(symbol.ContainingType, type))
            .Where(symbol => symbol is IFieldSymbol or IPropertySymbol or IEventSymbol or IMethodSymbol);
}
