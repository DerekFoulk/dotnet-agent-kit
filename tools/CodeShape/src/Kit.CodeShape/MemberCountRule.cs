using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>Finds types with more than <see cref="Limits.MembersPerType"/> members (CRF-011). A type's members are
/// the methods, constructors, finalizers, properties, indexers, events, fields and operators it declares, a field or
/// event declaration counting once for each name it lists, and a record's positional parameters, which the compiler
/// makes properties. A nested type isn't a member: it's measured on its own. A partial type is measured whole, across
/// its project's hand-written files, with a partial member counted once, and reported once, at its first part. What a
/// generator writes isn't counted, since nobody maintains it by hand.</summary>
internal static class MemberCountRule
{
    /// <summary>Checks the types of one project, whose hand-written files are read together so a partial type is
    /// seen whole.</summary>
    public static IEnumerable<Finding> Check(IReadOnlyList<SourceFile> files)
    {
        ArgumentNullException.ThrowIfNull(files);

        return files
            .Where(file => !file.Generated)
            .OrderBy(file => file.Path, StringComparer.Ordinal)
            .SelectMany(file => file.Parse().GetCompilationUnitRoot().DescendantNodes().OfType<TypeDeclarationSyntax>())
            .GroupBy(Identity, StringComparer.Ordinal)
            .Select(parts => (First: parts.First(), Count: MembersOf([.. parts])))
            .Where(type => type.Count > Limits.MembersPerType)
            .Select(type => Finding.At(
                type.First.SyntaxTree.FilePath,
                type.First.Identifier.GetLocation(),
                $"{type.First.Identifier.Text} has {type.Count} members; the limit is {Limits.MembersPerType} (CRF-011)."));
    }

    // What makes two declarations parts of one type: its namespace, the types it's nested in, its name and its
    // number of type parameters.
    private static string Identity(TypeDeclarationSyntax type) =>
        string.Join('.', type.AncestorsAndSelf().Reverse().Select(node => node switch
        {
            BaseNamespaceDeclarationSyntax space => space.Name.ToString(),
            TypeDeclarationSyntax outer => $"{outer.Identifier.Text}`{outer.Arity}",
            _ => null,
        }).OfType<string>());

    private static int MembersOf(IReadOnlyList<TypeDeclarationSyntax> parts)
    {
        MemberDeclarationSyntax[] members = [.. parts.SelectMany(part => part.Members)];
        int partial = members.Select(PartialKey).OfType<string>().Distinct(StringComparer.Ordinal).Count();
        return members.Where(member => PartialKey(member) is null).Sum(Count) + partial + PositionalProperties(parts, members);
    }

    // A field or event declaration declares a member for each name it lists; a nested type isn't a member here.
    private static int Count(MemberDeclarationSyntax member) => member switch
    {
        BaseFieldDeclarationSyntax field => field.Declaration.Variables.Count,
        BaseTypeDeclarationSyntax or DelegateDeclarationSyntax => 0,
        _ => 1,
    };

    // A partial member is declared in one part and implemented in another; both name it the same way.
    private static string? PartialKey(MemberDeclarationSyntax member) =>
        !member.Modifiers.Any(SyntaxKind.PartialKeyword) ? null : member switch
        {
            MethodDeclarationSyntax method => $"{method.Identifier.Text}`{method.Arity}{Types(method.ParameterList)}",
            ConstructorDeclarationSyntax constructor => $".ctor{Types(constructor.ParameterList)}",
            PropertyDeclarationSyntax property => property.Identifier.Text,
            IndexerDeclarationSyntax indexer => $"this{Types(indexer.ParameterList)}",
            EventDeclarationSyntax eventDeclaration => eventDeclaration.Identifier.Text,
            EventFieldDeclarationSyntax eventField => eventField.Declaration.Variables[0].Identifier.Text,
            _ => null,
        };

    private static string Types(BaseParameterListSyntax parameters) =>
        $"({string.Join(',', parameters.Parameters.Select(parameter => parameter.Type?.ToString()))})";

    // A record's positional parameters are properties the compiler declares for it, unless the record declares the
    // property itself. A class's or struct's primary constructor parameters aren't members.
    private static int PositionalProperties(IReadOnlyList<TypeDeclarationSyntax> parts, IEnumerable<MemberDeclarationSyntax> members)
    {
        HashSet<string> declared = [.. members.OfType<PropertyDeclarationSyntax>().Select(property => property.Identifier.Text)];
        return parts.OfType<RecordDeclarationSyntax>()
            .SelectMany(record => record.ParameterList?.Parameters ?? [])
            .Count(parameter => !declared.Contains(parameter.Identifier.Text));
    }
}
