using System.Collections.Immutable;
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

        SyntaxTree[] trees = [.. files.Select(file => file.Parse())];
        CSharpCompilation compilation = CSharpCompilation.Create("CodeShape", trees, s_runtime.Value);
        HashSet<INamedTypeSymbol> measured = new(SymbolEqualityComparer.Default);
        foreach (SyntaxTree tree in trees)
        {
            SemanticModel model = compilation.GetSemanticModel(tree);
            foreach (TypeDeclarationSyntax declaration in tree.GetRoot().DescendantNodes().OfType<TypeDeclarationSyntax>())
            {
                if (model.GetDeclaredSymbol(declaration) is not { } type || !measured.Add(type) || IsExempt(type))
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

            JoinDerivedState(declaration, type, model, sets);
        }

        return [.. methods.GroupBy(sets.Root, SymbolEqualityComparer.Default).Select(group => (IReadOnlyList<ISymbol>)[.. group])];
    }

    // State built from other state shares it. A property's accessors are methods (as LCOM4 counts them), so a
    // property joins the state it reads. A constructor isn't a method here, since it touches every field and would
    // make any class look cohesive; but a field or property it assigns from other state (an options object built
    // from a connection, say) is joined to that state. The kit's choices, beyond Hitz and Montazeri's LCOM4 (ADR-0050).
    private static void JoinDerivedState(TypeDeclarationSyntax declaration, INamedTypeSymbol type, SemanticModel model, DisjointSets sets)
    {
        foreach (BasePropertyDeclarationSyntax property in declaration.Members.OfType<BasePropertyDeclarationSyntax>())
        {
            if (model.GetDeclaredSymbol(property) is { IsStatic: false } symbol)
            {
                foreach (ISymbol used in InstanceMembersUsed(property, type, model))
                {
                    sets.Join(symbol, used);
                }
            }
        }

        IEnumerable<AssignmentExpressionSyntax> assignments = declaration.Members.OfType<ConstructorDeclarationSyntax>()
            .Where(constructor => !constructor.Modifiers.Any(SyntaxKind.StaticKeyword))
            .SelectMany(constructor => constructor.DescendantNodes().OfType<AssignmentExpressionSyntax>());
        foreach (AssignmentExpressionSyntax assignment in assignments)
        {
            if (model.GetSymbolInfo(assignment.Left).Symbol is { IsStatic: false } target
                && SymbolEqualityComparer.Default.Equals(target.ContainingType, type))
            {
                foreach (ISymbol used in InstanceMembersUsed(assignment.Right, type, model))
                {
                    sets.Join(target, used);
                }
            }
        }
    }

    // The type's own instance members that a body names.
    private static IEnumerable<ISymbol> InstanceMembersUsed(SyntaxNode body, INamedTypeSymbol type, SemanticModel model) =>
        body.DescendantNodes().OfType<SimpleNameSyntax>()
            .SelectMany(name => Meanings(model.GetSymbolInfo(name)))
            .Where(symbol => !symbol.IsStatic && SymbolEqualityComparer.Default.Equals(symbol.ContainingType, type))
            .Where(symbol => symbol is IFieldSymbol or IPropertySymbol or IEventSymbol or IMethodSymbol);

    // What a name binds to; when the compiler can't choose (an argument whose type it can't resolve, say), every
    // member the name could mean, so a call still joins its caller to the methods it may reach.
    private static ImmutableArray<ISymbol> Meanings(SymbolInfo info) => info.Symbol is { } symbol ? [symbol] : info.CandidateSymbols;
}
