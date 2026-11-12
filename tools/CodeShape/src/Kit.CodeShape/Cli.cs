using System.Text.Json;

namespace Kit.CodeShape;

/// <summary>The command line: Kit.CodeShape &lt;manifest.json&gt;, where the manifest is a JSON array of
/// <see cref="ProjectFiles"/>.</summary>
internal static class Cli
{
    private static readonly JsonSerializerOptions s_json = new(JsonSerializerDefaults.Web);

    /// <summary>Checks every project the manifest lists and prints each finding; returns 1 if there are any.</summary>
    public static int Run(IReadOnlyList<string> args, TextWriter output)
    {
        ArgumentNullException.ThrowIfNull(args);
        ArgumentNullException.ThrowIfNull(output);

        if (args.Count != 1)
        {
            output.WriteLine("Usage: Kit.CodeShape <manifest.json>");
            return 2;
        }

        ProjectFiles[] projects = JsonSerializer.Deserialize<ProjectFiles[]>(File.ReadAllText(args[0]), s_json) ?? [];
        int findings = 0;
        foreach (ProjectFiles project in projects)
        {
            foreach (Finding finding in ProjectCheck.Check(project))
            {
                // MSBuild's canonical error format, with the project in brackets as setup-dotnet's matcher expects.
                output.WriteLine($"{finding.Path}({finding.Line},{finding.Column}): error CRF008: {finding.Message} [{project.Name}]");
                findings++;
            }
        }

        if (findings > 0)
        {
            return 1;
        }

        int files = projects.Sum(project => project.Files.Count);
        output.WriteLine($"Code shape (CRF-008): {Count(projects.Length, "project")}, {Count(files, "file")}, no findings.");
        return 0;
    }

    private static string Count(int count, string noun) => count == 1 ? $"1 {noun}" : $"{count} {noun}s";
}
