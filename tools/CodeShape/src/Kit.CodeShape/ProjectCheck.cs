namespace Kit.CodeShape;

/// <summary>Runs every CRF-011 limit and STY-005's nullable rules over one project's hand-written files. Generated
/// files are read too, for the state a partial type declares in them, and reported on only when no tool wrote them
/// into source: outside the project's EF Core Migrations folder, and not a .resx file's designer (STY-005).</summary>
internal static class ProjectCheck
{
    public static IEnumerable<Finding> Check(ProjectFiles project)
    {
        ArgumentNullException.ThrowIfNull(project);

        SourceFile[] files = [.. project.Files.Select(path => Read(path, project))];
        // The owner, 2026-11-16: a test's ! follows an assertion or passes null on purpose to test a guard, so a test
        // project (a name ending in Tests, as STY-015 and CA2007 have it) needs no label on it (STY-005).
        bool isTestProject = Path.GetFileNameWithoutExtension(project.Name).EndsWith("Tests", StringComparison.Ordinal);
        return files
            .Where(file => !file.Generated)
            .SelectMany(file => NestingRule.Check(file)
                .Concat(StatementRule.Check(file))
                .Concat(FileLengthRule.Check(file))
                .Concat(NullableDirectiveRule.Check(file))
                .Concat(isTestProject ? [] : NullForgivingRule.Check(file)))
            .Concat(files.SelectMany(GeneratedMarkerRule.Check))
            .Concat(PublicTypeRule.Check(files))
            .Concat(CohesionRule.Check(files))
            .Concat(MemberCountRule.Check(files))
            .OrderBy(finding => finding.Path, StringComparer.Ordinal)
            .ThenBy(finding => finding.Line)
            .ThenBy(finding => finding.Column);
    }

    /// <summary>The project's files that aren't generated code, which the limits and the duplicate finder report on.</summary>
    public static IEnumerable<SourceFile> HandWritten(ProjectFiles project)
    {
        ArgumentNullException.ThrowIfNull(project);

        return project.Files.Select(path => Read(path, project)).Where(file => !file.Generated);
    }

    private static SourceFile Read(string path, ProjectFiles project)
    {
        IReadOnlyList<string> defines = project.Defines;
        string projectFolder = Path.GetDirectoryName(project.Name) ?? string.Empty;
        SourceFile file = new(path, File.ReadAllText(path)) { Defines = defines, ProjectFolder = projectFolder };
        return file with { Generated = GeneratedCode.Is(file) };
    }
}
