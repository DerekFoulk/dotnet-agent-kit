namespace Kit.CodeShape;

/// <summary>Finds a hand-written file marked as generated code outside an EF Core Migrations folder: the compiler treats
/// such a file as nullable-disabled and its analyzers skip it, as these checks and the coverage gate do, so a marker
/// on a hand-written file takes it out of STY-005, CRF-011 and TST-004 unseen (STY-005).</summary>
internal static class GeneratedMarkerRule
{
    /// <summary>The folder EF Core writes its migrations to, which it marks as generated.</summary>
    private const string MigrationsFolder = "Migrations";

    private const string Message =
        "The file is marked as generated code, which the compiler's nullable analysis, its analyzers and these checks skip; only EF Core migrations, in a Migrations folder, may be (STY-005).";

    public static IEnumerable<Finding> Check(SourceFile file)
    {
        ArgumentNullException.ThrowIfNull(file);

        return file.Generated && !InMigrations(file.Path) ? [new Finding(file.Path, 1, 1, Message) { Rule = "STY005" }] : [];
    }

    private static bool InMigrations(string path) =>
        path.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar).SkipLast(1)
            .Contains(MigrationsFolder, StringComparer.OrdinalIgnoreCase);
}
