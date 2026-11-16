using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;

namespace Kit.CodeShape;

/// <summary>One project's files compiled together, so a rule can ask the compiler what a type is and what it declares:
/// a partial type's parts are one symbol, and a file-local type is its own. Generated files are compiled too, for what
/// they declare.</summary>
/// <param name="Compilation">The project's files, compiled against the running .NET's own assemblies.</param>
/// <param name="HandWritten">The syntax trees of the files that aren't generated, in path order.</param>
internal sealed record CompiledProject(CSharpCompilation Compilation, IReadOnlyList<SyntaxTree> HandWritten)
{
    // The running .NET's own assemblies, a documented runtime property. They let the compiler bind the code's own
    // members; a project's packages aren't needed for that, and types from them stay unresolved, which the rules ignore.
    private static readonly Lazy<MetadataReference[]> s_runtime = new(() =>
        // CRF-001 safety net: the .NET host sets TRUSTED_PLATFORM_ASSEMBLIES for every app it starts.
        [.. ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!)
            .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries)
            .Select(path => MetadataReference.CreateFromFile(path))]);

    /// <summary>Compiles one project's files.</summary>
    public static CompiledProject Of(IReadOnlyList<SourceFile> files)
    {
        ArgumentNullException.ThrowIfNull(files);

        (SourceFile File, SyntaxTree Tree)[] parsed = [.. files.Select(file => (file, file.Parse()))];
        return new(
            CSharpCompilation.Create("CodeShape", parsed.Select(pair => pair.Tree), s_runtime.Value),
            [.. parsed.Where(pair => !pair.File.Generated).Select(pair => pair.Tree).OrderBy(tree => tree.FilePath, StringComparer.Ordinal)]);
    }
}
