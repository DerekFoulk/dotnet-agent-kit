using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace Kit.CodeShape;

/// <summary>What makes two declarations parts of one type: its namespace, the types it's nested in, its name and its
/// number of type parameters.</summary>
internal static class TypeIdentity
{
    /// <summary>The type's identity, the same for each of a partial type's declarations.</summary>
    public static string Of(MemberDeclarationSyntax type)
    {
        ArgumentNullException.ThrowIfNull(type);

        return string.Join('.', type.AncestorsAndSelf().Reverse().Select(node => node switch
        {
            BaseNamespaceDeclarationSyntax space => space.Name.ToString(),
            TypeDeclarationSyntax declared => $"{declared.Identifier.Text}`{declared.Arity}",
            DelegateDeclarationSyntax declared => $"{declared.Identifier.Text}`{declared.Arity}",
            EnumDeclarationSyntax declared => declared.Identifier.Text,
            _ => null,
        }).OfType<string>());
    }
}
