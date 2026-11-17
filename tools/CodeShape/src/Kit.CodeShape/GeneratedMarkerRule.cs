namespace Kit.CodeShape;

/// <summary>Finds a file marked as generated code that no tool keeps in source: the compiler treats such a file as
/// nullable-disabled and its analyzers skip it, as these checks and the coverage gate do, so a marker on a hand-written
/// file takes it out of STY-005, CRF-011 and TST-004 unseen (STY-005). The two kinds a tool writes into source are left
/// alone: EF Core's migrations, and a .resx file's designer beside it.</summary>
internal static class GeneratedMarkerRule
{
    private const string DesignerSuffix = ".Designer.cs";

    private const string Message =
        "The file is marked as generated code, which the compiler's nullable analysis, its analyzers and these checks skip; only EF Core migrations, in a Migrations folder, and a .resx file's designer may be (STY-005).";

    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        bool written = file.Generated && !EfCoreMigrations.Contains(file.Path, file.ProjectFolder) && !IsResourceDesigner(file.Path);
        return written ? [new Finding(file.Path, 1, 1, Message) { Rule = RuleCodes.Nullable }] : [];
    }

    private static bool IsResourceDesigner(string path) =>
        path.EndsWith(DesignerSuffix, StringComparison.OrdinalIgnoreCase)
        && File.Exists(string.Concat(path.AsSpan(0, path.Length - DesignerSuffix.Length), ".resx"));
}
