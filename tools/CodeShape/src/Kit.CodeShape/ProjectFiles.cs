namespace Kit.CodeShape;

/// <summary>One project's C# source files, as Test-CodeShape.ps1 reads them from MSBuild's Compile items.</summary>
/// <param name="Name">The project file, as findings name it.</param>
/// <param name="Defines">The project's preprocessor symbols (its DefineConstants).</param>
/// <param name="Files">The full paths of its source files.</param>
internal sealed record ProjectFiles(string Name, IReadOnlyList<string> Defines, IReadOnlyList<string> Files);
