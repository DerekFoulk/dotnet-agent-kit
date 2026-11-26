namespace Kit.AppTests.Hosting;

/// <summary>
/// Finds an app project's folder, for a test host's content root (ADR-0095). This part is the kit's (tools/AppTests in
/// the kit, .kit/tools/AppTests in an app), compiled into every FunctionalTests and E2E.Tests project. A
/// WebApplicationFactory sets its content root with it because the factory's own lookup goes wrong under Stryker.NET
/// (ADR-0039), and a path relative to the solution holds in one repo's layout only: the kit's sample is under sample/,
/// an app's projects at its root.
/// </summary>
internal static class ProjectFolder
{
    /// <summary>
    /// Gets the nearest src/<paramref name="projectName"/> folder in <paramref name="start"/> or a folder above it, such
    /// as a test's AppContext.BaseDirectory.
    /// </summary>
    public static string Find(string start, string projectName) => Path.Combine(start, "src", projectName);
}
