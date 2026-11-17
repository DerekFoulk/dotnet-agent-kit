using System.Text.Json;

namespace Kit.AppTests.Architecture;

/// <summary>
/// The app's part of <see cref="AppLayers"/> names every layer project the tests reference, so a module added later
/// isn't left unchecked.
/// </summary>
public sealed class DeclarationTests
{
    // The project-name endings that say a project is a layer (ARC-001): presentation is an API, a web UI or the layer's
    // own name.
    private static readonly string[] s_layerEndings = [".Domain", ".Contracts", ".Application", ".Infrastructure", ".Api", ".Web", ".Presentation"];

    [Fact]
    public void TheAppDeclaresAtLeastOneAssembly() =>
        AppLayers.All.Should().NotBeEmpty("an Architecture.Tests project checks the app's layers, so it names them in AppLayers");

    [Fact]
    public void NoAssemblyIsDeclaredInTwoLayers() =>
        AppLayers.All.GroupBy(assembly => assembly.GetName().Name, StringComparer.Ordinal).Where(group => group.Count() > 1)
            .Select(group => group.Key).Should().BeEmpty("each assembly is in one layer, whose rules it follows");

    // The test project's .deps.json lists the projects it references, directly or through others, with "type":
    // "project"; packages, whose names can end the same way (Microsoft.AspNetCore.Components.Web), are "package".
    [Fact]
    public void EveryLayerProjectTheTestsReferenceIsDeclared() =>
        ReferencedProjects().Where(name => s_layerEndings.Any(ending => name.EndsWith(ending, StringComparison.Ordinal)))
            .Except(AppLayers.All.Select(assembly => assembly.GetName().Name!), StringComparer.Ordinal)
            .Should().BeEmpty("each is a layer by its name; declare it in AppLayers, in the app's part");

    private static IEnumerable<string> ReferencedProjects()
    {
        string tests = typeof(DeclarationTests).Assembly.GetName().Name!;
        using JsonDocument deps = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, tests + ".deps.json")));
        return [.. deps.RootElement.GetProperty("libraries").EnumerateObject()
            .Where(library => library.Value.GetProperty("type").GetString() == "project")
            .Select(library => library.Name.Split('/')[0])
            .Where(name => name != tests)];
    }
}
