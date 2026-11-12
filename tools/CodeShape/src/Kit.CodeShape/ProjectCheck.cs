namespace Kit.CodeShape;

/// <summary>Runs every CRF-011 limit over one project's hand-written files. Generated files are read too, for the
/// state a partial type declares in them, but never reported on.</summary>
internal static class ProjectCheck
{
    public static IEnumerable<Finding> Check(ProjectFiles project)
    {
        ArgumentNullException.ThrowIfNull(project);

        SourceFile[] files = [.. project.Files.Select(path => Read(path, project.Defines))];
        return files
            .Where(file => !file.Generated)
            .SelectMany(file => NestingRule.Check(file).Concat(StatementRule.Check(file)).Concat(FileLengthRule.Check(file)))
            .Concat(CohesionRule.Check(files))
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
