using System.Collections.Immutable;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds types whose methods fall into more than <see cref="Limits.Lcom4"/> groups that share no state
/// (LCOM4; CRF-011, ADR-0050).</summary>
internal static class CohesionRule
{
    /// <summary>Checks the types of one project, whose files are compiled together so a partial type is seen whole.
    /// Generated files are read for what they declare, and never reported on.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        CompiledProject project = CompiledProject.Of(files);
        CSharpCompilation compilation = project.Compilation;
        HashSet<INamedTypeSymbol> measured = new(SymbolEqualityComparer.Default);
        foreach (SyntaxTree tree in project.HandWritten)
        {
            SemanticModel model = compilation.GetSemanticModel(tree);
            foreach (TypeDeclarationSyntax declaration in tree.GetRoot().DescendantNodes().OfType<TypeDeclarationSyntax>())
            {
                if (model.GetDeclaredSymbol(declaration) is not { } type || !measured.Add(type) || LimitExemption.CoversType(type))
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

    // The type's methods that use its instance state, grouped by what they share, in declaration order. A property
    // isn't a method here: it links the state it reads (JoinDerivedState), or every options class and record with two
    // computed properties over different state would look like two classes.
    private static IReadOnlyList<IReadOnlyList<ISymbol>> Groups(INamedTypeSymbol type, Compilation compilation)
    {
        DisjointSets sets = new();
        List<ISymbol> methods = [];
        foreach (TypeDeclarationSyntax declaration in type.DeclaringSyntaxReferences.Select(reference => reference.GetSyntax()).OfType<TypeDeclarationSyntax>())
        {
            SemanticModel model = compilation.GetSemanticModel(declaration.SyntaxTree);
            foreach (MethodDeclarationSyntax member in declaration.Members.OfType<MethodDeclarationSyntax>())
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

    // State built from other state shares it. A property or indexer links the state it reads. A constructor isn't a
    // method here, since it touches every field and would make any class look cohesive; but a field or property it
    // assigns from other state (an options object built from a connection, say) is joined to that state, and so is one
    // initialized from other state, such as a primary constructor's parameter. The kit's choices, beyond Hitz and
    // Montazeri's LCOM4 (ADR-0050).
    private static void JoinDerivedState(TypeDeclarationSyntax declaration, INamedTypeSymbol type, SemanticModel model, DisjointSets sets)
    {
        IEnumerable<(ISymbol? Target, ExpressionSyntax Source)> assignments = declaration.Members.OfType<ConstructorDeclarationSyntax>()
            .Where(constructor => !constructor.Modifiers.Any(SyntaxKind.StaticKeyword))
            .SelectMany(constructor => constructor.DescendantNodes().OfType<AssignmentExpressionSyntax>())
            .Select(assignment => (model.GetSymbolInfo(assignment.Left).Symbol, assignment.Right));
        IEnumerable<(ISymbol? Target, ExpressionSyntax Source)> fieldInitializers = declaration.Members.OfType<FieldDeclarationSyntax>()
            .SelectMany(field => field.Declaration.Variables)
            .Where(variable => variable.Initializer is not null)
            // CRF-001 safety net: the Where above keeps only variables with an initializer, which the compiler can't see.
            .Select(variable => (model.GetDeclaredSymbol(variable), variable.Initializer!.Value));
        // A property's whole declaration: what its accessors read, and its initializer.
        IEnumerable<(ISymbol? Target, SyntaxNode Source)> properties = declaration.Members.OfType<BasePropertyDeclarationSyntax>()
            .Select(property => (model.GetDeclaredSymbol(property), (SyntaxNode)property));

        foreach ((ISymbol? target, SyntaxNode source) in assignments.Concat(fieldInitializers)
            .Select(pair => (pair.Target, (SyntaxNode)pair.Source)).Concat(properties))
        {
            // Only the type's own instance state is joined: a static field, a local or a static property built from
            // two fields would otherwise join them through itself.
            if (target is { IsStatic: false } && IsStateOf(target, type))
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
        body.DescendantNodesAndSelf().OfType<SimpleNameSyntax>() // a source may be just a name: _b = _a
            .SelectMany(name => Meanings(model.GetSymbolInfo(name)))
            .Select(symbol => symbol.OriginalDefinition) // a call to Helper<int> means the method declared as Helper<T>
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
