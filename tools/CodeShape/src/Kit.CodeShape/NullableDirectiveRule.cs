using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;

namespace Kit.CodeShape;

/// <summary>Finds #nullable directives, which change the nullable context the project sets (STY-005; the nullable
/// migration page's end state: https://learn.microsoft.com/dotnet/csharp/nullable-migration-strategies). EF Core's
/// migrations carry one, so EF Core's own migration files are left alone (EfCoreMigrations).</summary>
internal static class NullableDirectiveRule
{
    private const string Message = "#nullable changes the nullable context the project sets; nullable stays on in every file (STY-005).";

    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        return EfCoreMigrations.Contains(file.Path, file.ProjectFolder)
            ? []
            : file.Parse().GetRoot().DescendantTrivia(descendIntoTrivia: true)
                .Where(trivia => trivia.IsKind(SyntaxKind.NullableDirectiveTrivia))
                .Select(trivia => Finding.At(file.Path, trivia.GetLocation(), Message) with { Rule = RuleCodes.Nullable });
    }
}
