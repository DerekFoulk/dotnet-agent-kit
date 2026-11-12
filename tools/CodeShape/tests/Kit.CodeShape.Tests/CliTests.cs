using System.Text.Json;

namespace Kit.CodeShape.Tests;

// The command line reads a manifest of each project's source files, as Test-CodeShape.ps1 writes it, and prints
// each finding in MSBuild's error format, which setup-dotnet's problem matcher turns into a PR annotation.
public sealed class CliTests : IDisposable
{
    private readonly DirectoryInfo _folder = Directory.CreateTempSubdirectory("codeshape-");

    public void Dispose() => _folder.Delete(recursive: true);

    [Fact]
    public void EachFindingIsPrintedInMSBuildsErrorFormatAndTheRunFails()
    {
        string deep = Write("Deep.cs", """
            class Deep
            {
                void Run(int a)
                {
                    if (a > 0) { if (a > 1) { if (a > 2) { if (a > 3) { if (a > 4) { a++; } } } } }
                }
            }
            """);
        string project = Path.Join(_folder.FullName, "App.csproj");

        (int exitCode, string output) = Run(new { name = project, defines = Array.Empty<string>(), files = new[] { deep } });

        exitCode.Should().Be(1);
        output.Should().Be(
            $"{deep}(5,74): error CRF008: Run nests 5 levels deep; the limit is 4 (CRF-008). [{project}]{Environment.NewLine}");
    }

    [Fact]
    public void ARunWithNoFindingsSaysSoAndPasses()
    {
        string tidy = Write("Tidy.cs", "class Tidy { void Run() { } }");

        (int exitCode, string output) = Run(new { name = "App.csproj", defines = Array.Empty<string>(), files = new[] { tidy } });

        exitCode.Should().Be(0);
        output.Should().Be($"Code shape (CRF-008): 1 project, 1 file, no findings.{Environment.NewLine}");
    }

    // Test-Duplication.ps1 hands the duplicate finder the same hand-written files, so generated code is skipped by
    // one rule in one place (CRF-003).
    [Fact]
    public void WithFilesItListsEachHandWrittenFileAndChecksNothing()
    {
        string tidy = Write("Tidy.cs", "class Tidy { }");
        string generated = Write("Tidy.g.cs", "class Generated { }");
        string manifest = Path.Join(_folder.FullName, "manifest.json");
        File.WriteAllText(manifest, JsonSerializer.Serialize(new[] { new { name = "App.csproj", defines = Array.Empty<string>(), files = new[] { tidy, generated } } }));
        using StringWriter output = new();

        int exitCode = Cli.Run(["--files", manifest], output);

        exitCode.Should().Be(0);
        output.ToString().Should().Be($"{tidy}{Environment.NewLine}");
    }

    private string Write(string name, string text)
    {
        string path = Path.Join(_folder.FullName, name);
        File.WriteAllText(path, text);
        return path;
    }

    private (int ExitCode, string Output) Run(params object[] projects)
    {
        string manifest = Path.Join(_folder.FullName, "manifest.json");
        File.WriteAllText(manifest, JsonSerializer.Serialize(projects));
        using StringWriter output = new();
        int exitCode = Cli.Run([manifest], output);
        return (exitCode, output.ToString());
    }
}
