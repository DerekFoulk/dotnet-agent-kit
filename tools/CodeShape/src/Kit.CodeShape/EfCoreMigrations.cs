namespace Kit.CodeShape;

/// <summary>Where EF Core's generated migrations live: a folder named Migrations, which `dotnet ef migrations add` writes
/// to (DAT-005). EF Core writes #nullable disable into every migration and marks only the designer file and the model
/// snapshot as generated, so STY-005's rules leave this folder alone.</summary>
internal static class EfCoreMigrations
{
    private const string Folder = "Migrations";

    /// <summary>Whether a file sits in a Migrations folder inside its project, so a folder the repo itself sits in
    /// doesn't count.</summary>
    public static bool Contains(string path, string projectFolder = "")
    {
        ArgumentNullException.ThrowIfNull(path);
        ArgumentNullException.ThrowIfNull(projectFolder);

        string inProject = projectFolder.Length == 0 ? path : Path.GetRelativePath(projectFolder, path);
        return inProject.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar).SkipLast(1)
            .Contains(Folder, StringComparer.OrdinalIgnoreCase);
    }
}
