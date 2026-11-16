namespace Kit.CodeShape;

/// <summary>Runs every CRF-011 limit and STY-005's nullable rules over one project's hand-written files. Generated
/// files are read too, for the state a partial type declares in them, and reported on only when they sit outside an
/// EF Core Migrations folder (STY-005).</summary>
internal static class ProjectCheck
{
    public static IEnumerable<Finding> Check(ProjectFiles project)
    {
        ArgumentNullException.ThrowIfNull(project);

        SourceFile[] files = [.. project.Files.Select(path => Read(path, project.Defines))];
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

        return project.Files.Select(path => Read(path, project.Defines)).Where(file => !file.Generated);
    }

    private static SourceFile Read(string path, IReadOnlyList<string> defines)
    {
        SourceFile file = new(path, File.ReadAllText(path)) { Defines = defines };
        return file with { Generated = GeneratedCode.Is(file) };
    }
}
