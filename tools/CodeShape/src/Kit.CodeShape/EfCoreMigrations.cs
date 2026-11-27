namespace Kit.CodeShape;

/// <summary>The files `dotnet ef migrations add` writes into a folder named Migrations (DAT-005): each migration,
/// &lt;timestamp&gt;_&lt;Name&gt;.cs, its Designer file, and the model snapshot, &lt;Context&gt;ModelSnapshot.cs. EF Core
/// writes #nullable disable into every migration and marks only the designer file and the model snapshot as generated,
/// so STY-005's rules leave these files alone. A file of the app's own in that folder is checked like any other, as
/// .editorconfig's generated_code section has it (the same names, GAP-025).</summary>
internal static class EfCoreMigrations
{
    private const string Folder = "Migrations";

    private const string SnapshotSuffix = "ModelSnapshot.cs";

    /// <summary>Whether a file is one EF Core wrote in a Migrations folder inside its project, so a folder the repo
    /// itself sits in doesn't count.</summary>
    public static bool Contains(string path, string projectFolder = "")
    {
        ArgumentNullException.ThrowIfNull(path);
        ArgumentNullException.ThrowIfNull(projectFolder);

        string inProject = projectFolder.Length == 0 ? path : Path.GetRelativePath(projectFolder, path);
        bool inFolder = inProject.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar).SkipLast(1)
            .Contains(Folder, StringComparer.OrdinalIgnoreCase);
        return inFolder && IsEfCoreName(Path.GetFileName(inProject));
    }

    /// <summary>A migration's name starts with its timestamp and an underscore before its own name (its Designer file's
    /// too), as .editorconfig's [0-9]*_*.cs matches it; the snapshot's ends in ModelSnapshot.cs.</summary>
    private static bool IsEfCoreName(string name) =>
        name.EndsWith(".cs", StringComparison.Ordinal)
        && ((char.IsAsciiDigit(name[0]) && name.Contains('_', StringComparison.Ordinal))
            || name.EndsWith(SnapshotSuffix, StringComparison.Ordinal));
}
