using System.Collections.Immutable;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds types whose methods fall into more than <see cref="Limits.Lcom4"/> groups that share no state
/// (LCOM4; CRF-011, ADR-0050).</summary>
internal static class CohesionRule
{
    // The running .NET's own assemblies, a documented runtime property. They let the compiler bind the code's own
    // members; a project's packages aren't needed for that, and types from them stay unresolved, which LCOM4 ignores.
    private static readonly Lazy<MetadataReference[]> s_runtime = new(() =>
        [.. ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!)
            .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries)
            .Select(path => MetadataReference.CreateFromFile(path))]);

    /// <summary>Checks the types of one project, whose files are compiled together so a partial type is seen whole.
    /// Generated files are read for what they declare, and never reported on.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        ArgumentNullException.ThrowIfNull(files);

        (SourceFile File, SyntaxTree Tree)[] parsed = [.. files.Select(file => (file, file.Parse()))];
        CSharpCompilation compilation = CSharpCompilation.Create("CodeShape", parsed.Select(pair => pair.Tree), s_runtime.Value);
        HashSet<INamedTypeSymbol> measured = new(SymbolEqualityComparer.Default);
        foreach (SyntaxTree tree in parsed.Where(pair => !pair.File.Generated).Select(pair => pair.Tree))
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
                    string listed = string.Join(", ", groups.Select(group => $"[{string.Join(", ", group.Select(member => member.Name))}]"));
                    yield return Finding.At(
                        tree.FilePath,
                        declaration.Identifier.GetLocation(),
                        $"{type.Name}'s methods form {groups.Count} groups that share no state (LCOM4 {groups.Count}; the limit is {Limits.Lcom4}): {listed} (CRF-011).");
                }
            }
        }
    }

    // A partial type is exempt when any of its declarations carries the exception.
    private static bool IsExempt(INamedTypeSymbol type) =>
        type.DeclaringSyntaxReferences.Any(reference => LimitException.Covers(reference.GetSyntax()));

    // The type's methods that use its instance state, grouped by what they share, in declaration order. A property
    // or indexer with a body is a method too (its accessors are), as LCOM4 counts them; an auto-property is state.
    private static IReadOnlyList<IReadOnlyList<ISymbol>> Groups(INamedTypeSymbol type, Compilation compilation)
    {
        DisjointSets sets = new();
        List<ISymbol> methods = [];
        foreach (TypeDeclarationSyntax declaration in type.DeclaringSyntaxReferences.Select(reference => reference.GetSyntax()).OfType<TypeDeclarationSyntax>())
        {
            SemanticModel model = compilation.GetSemanticModel(declaration.SyntaxTree);
            foreach (MemberDeclarationSyntax member in declaration.Members.Where(IsMethodLike))
            {
                if (model.GetDeclaredSymbol(member) is not { IsStatic: false } symbol)
                {
                    continue;
                }

                ISymbol[] uses = [.. InstanceStateUsed(member, type, model).Where(used => !SymbolEqualityComparer.Default.Equals(used, symbol))];
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

    private static bool IsMethodLike(MemberDeclarationSyntax member) => member switch
    {
        MethodDeclarationSyntax => true,
        PropertyDeclarationSyntax property => property.ExpressionBody is not null || HasAccessorBody(property.AccessorList),
        IndexerDeclarationSyntax indexer => indexer.ExpressionBody is not null || HasAccessorBody(indexer.AccessorList),
        _ => false,
    };

    private static bool HasAccessorBody(AccessorListSyntax? accessors) =>
        accessors?.Accessors.Any(accessor => accessor.Body is not null || accessor.ExpressionBody is not null) == true;

    // State built from other state shares it. A constructor isn't a method here, since it touches every field and
    // would make any class look cohesive; but a field or property it assigns from other state (an options object
    // built from a connection, say) is joined to that state, and so is one initialized from other state, such as a
    // primary constructor's parameter. The kit's choices, beyond Hitz and Montazeri's LCOM4 (ADR-0050).
    private static void JoinDerivedState(TypeDeclarationSyntax declaration, INamedTypeSymbol type, SemanticModel model, DisjointSets sets)
    {
        IEnumerable<(ISymbol? Target, ExpressionSyntax Source)> assignments = declaration.Members.OfType<ConstructorDeclarationSyntax>()
            .Where(constructor => !constructor.Modifiers.Any(SyntaxKind.StaticKeyword))
            .SelectMany(constructor => constructor.DescendantNodes().OfType<AssignmentExpressionSyntax>())
            .Select(assignment => (model.GetSymbolInfo(assignment.Left).Symbol, assignment.Right));
        IEnumerable<(ISymbol? Target, ExpressionSyntax Source)> fieldInitializers = declaration.Members.OfType<FieldDeclarationSyntax>()
            .SelectMany(field => field.Declaration.Variables)
            .Where(variable => variable.Initializer is not null)
            .Select(variable => (model.GetDeclaredSymbol(variable), variable.Initializer!.Value));
        IEnumerable<(ISymbol? Target, ExpressionSyntax Source)> propertyInitializers = declaration.Members.OfType<PropertyDeclarationSyntax>()
            .Where(property => property.Initializer is not null)
            .Select(property => ((ISymbol?)model.GetDeclaredSymbol(property), property.Initializer!.Value));

        foreach ((ISymbol? target, ExpressionSyntax source) in assignments.Concat(fieldInitializers).Concat(propertyInitializers))
        {
            if (target is { IsStatic: false } && SymbolEqualityComparer.Default.Equals(target.ContainingSymbol, type))
            {
                foreach (ISymbol used in InstanceStateUsed(source, type, model))
                {
                    sets.Join(target, used);
                }
            }
        }
    }

    // The type's own instance state and members that a body names: its fields, properties, events and methods (not a
    // local function, which belongs to its method), and its primary constructor's parameters, which the compiler
    // keeps for the type's members as state.
    private static IEnumerable<ISymbol> InstanceStateUsed(SyntaxNode body, INamedTypeSymbol type, SemanticModel model) =>
        body.DescendantNodes().OfType<SimpleNameSyntax>()
            .SelectMany(name => Meanings(model.GetSymbolInfo(name)))
            .Where(symbol => !symbol.IsStatic && IsStateOf(symbol, type));

    private static bool IsStateOf(ISymbol symbol, INamedTypeSymbol type) => symbol switch
    {
        IFieldSymbol or IPropertySymbol or IEventSymbol or IMethodSymbol => SymbolEqualityComparer.Default.Equals(symbol.ContainingSymbol, type),
        IParameterSymbol { ContainingSymbol: IMethodSymbol { MethodKind: MethodKind.Constructor } constructor } =>
            SymbolEqualityComparer.Default.Equals(constructor.ContainingType, type)
            && constructor.DeclaringSyntaxReferences.Any(reference => reference.GetSyntax() is TypeDeclarationSyntax),
        _ => false,
    };

    // What a name binds to; when the compiler can't choose (an argument whose type it can't resolve, say), every
    // member the name could mean, so a call still joins its caller to the methods it may reach.
    private static ImmutableArray<ISymbol> Meanings(SymbolInfo info) => info.Symbol is { } symbol ? [symbol] : info.CandidateSymbols;
}
