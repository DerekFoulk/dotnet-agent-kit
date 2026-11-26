using Kit.AppTests.Hosting;

namespace Bookmarks.FunctionalTests;

/// <summary>
/// The kit's ProjectFolder finds an app project's folder from a test's output folder, whatever folder holds the
/// solution (ADR-0095): the sample's tests run under sample/, an app's at its root.
/// </summary>
public sealed class ProjectFolderTests : IDisposable
{
    private const string ProjectName = "Contoso.Api";

    private readonly DirectoryInfo _root = Directory.CreateTempSubdirectory("project-folder-");

    [Fact]
    public void FindReturnsTheNearestSrcFolderOfTheProjectAboveTheStart()
    {
        string expected = Directory.CreateDirectory(Path.Combine(_root.FullName, "src", ProjectName)).FullName;
        string start = Directory.CreateDirectory(Path.Combine(_root.FullName, "tests", "Contoso.FunctionalTests", "bin", "Release", "net10.0")).FullName;

        string found = ProjectFolder.Find(start, ProjectName);

        found.Should().Be(expected);
    }

    [Fact]
    public void FindThrowsWhenNoFolderAboveTheStartHoldsTheProject()
    {
        string start = Directory.CreateDirectory(Path.Combine(_root.FullName, "tests", "Contoso.FunctionalTests", "bin")).FullName;

        Action find = () => ProjectFolder.Find(start, ProjectName);

        find.Should().Throw<DirectoryNotFoundException>().WithMessage($"*{ProjectName}*");
    }

    public void Dispose() => _root.Delete(recursive: true);
}
