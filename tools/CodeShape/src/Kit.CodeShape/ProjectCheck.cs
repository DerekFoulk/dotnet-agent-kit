namespace Kit.CodeShape;

/// <summary>Runs every CRF-008 limit over one project's hand-written files.</summary>
internal static class ProjectCheck
{
    public static IEnumerable<Finding> Check(ProjectFiles project)
    {
        ArgumentNullException.ThrowIfNull(project);

        SourceFile[] files = [.. HandWritten(project)];
        return files
            .SelectMany(file => NestingRule.Check(file).Concat(StatementRule.Check(file)).Concat(FileLengthRule.Check(file)))
            .Concat(CohesionRule.Check(files))
            .OrderBy(finding => finding.Path, StringComparer.Ordinal)
            .ThenBy(finding => finding.Line)
            .ThenBy(finding => finding.Column);
    }

    /// <summary>The project's files that aren't generated code, which the limits and the duplicate finder read.</summary>
    public static IEnumerable<SourceFile> HandWritten(ProjectFiles project)
    {
        ArgumentNullException.ThrowIfNull(project);

        return project.Files
            .Select(path => new SourceFile(path, File.ReadAllText(path)) { Defines = project.Defines })
            .Where(file => !GeneratedCode.Is(file));
    }
}
