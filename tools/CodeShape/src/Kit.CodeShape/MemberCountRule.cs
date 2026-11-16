using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds classes, structs, interfaces and records with more than <see cref="Limits.MembersPerType"/> members
/// (CRF-011); an enum's values are data, so enums aren't measured. The compiler says what a type declares, so a
/// partial type is one type, with a partial member counted once, and a file-local type is its own type, whatever its
/// name. A type's members are the methods, constructors, finalizers, properties, indexers, events, fields and
/// operators written in it, a record's positional parameters, which the compiler makes properties, and the members of
/// its C# 14 extension blocks, which the compiler declares in it, so a block isn't measured on its own. What the
/// compiler adds on its own (a record's equality members, a default constructor, an accessor) isn't counted, nor is a
/// primary constructor, nor a member only a generator declares, since nobody maintains it by hand. A nested type isn't
/// a member: it's measured on its own. A type is reported once, at its first hand-written part, and its exception
/// marker covers its member count (<see cref="LimitExemption"/>).</summary>
internal static class MemberCountRule
{
    /// <summary>Checks the types of one project, whose files are compiled together so a partial type is seen whole.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        CompiledProject project = CompiledProject.Of(files);
        HashSet<SyntaxTree> handWritten = [.. project.HandWritten];
        HashSet<INamedTypeSymbol> measured = new(SymbolEqualityComparer.Default);
        foreach (SyntaxTree tree in project.HandWritten)
        {
            SemanticModel model = project.Compilation.GetSemanticModel(tree);
            foreach (TypeDeclarationSyntax declaration in tree.GetRoot().DescendantNodes().OfType<TypeDeclarationSyntax>())
            {
                if (model.GetDeclaredSymbol(declaration) is not { IsExtension: false } type
                    || !measured.Add(type)
                    || LimitExemption.CoversType(type))
                {
                    continue;
                }

                int count = MembersOf(type, handWritten);
                if (count > Limits.MembersPerType)
                {
                    yield return Finding.At(
                        tree.FilePath,
                        declaration.Identifier.GetLocation(),
                        $"{type.Name} has {count} members; the limit is {Limits.MembersPerType} (CRF-011).");
                }
            }
        }
    }

    // An extension block's members are its class's: the compiler declares them there.
    private static int MembersOf(INamedTypeSymbol type, HashSet<SyntaxTree> handWritten) =>
        type.GetMembers().Count(member => IsWritten(member, handWritten))
        + type.GetTypeMembers().Where(nested => nested.IsExtension).Sum(extension => MembersOf(extension, handWritten));

    // A member someone wrote in a hand-written file. An accessor belongs to its property or event, and a primary
    // constructor is declared by its type: its parameters are the type's state, not members, unless the type is a
    // record, whose properties for them count.
    private static bool IsWritten(ISymbol member, HashSet<SyntaxTree> handWritten) =>
        !member.IsImplicitlyDeclared
        && member is not INamedTypeSymbol
        && member is not IMethodSymbol { AssociatedSymbol: not null }
        && member.DeclaringSyntaxReferences.Any(reference => handWritten.Contains(reference.SyntaxTree))
        && !member.DeclaringSyntaxReferences.Any(reference => reference.GetSyntax() is TypeDeclarationSyntax);
}
