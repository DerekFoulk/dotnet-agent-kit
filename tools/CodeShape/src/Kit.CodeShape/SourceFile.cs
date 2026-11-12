using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;

namespace Kit.CodeShape;

/// <summary>A C# source file and the preprocessor symbols its project defines.</summary>
/// <param name="Path">The file's path, as findings report it.</param>
/// <param name="Text">The file's text.</param>
internal sealed record SourceFile(string Path, string Text)
{
    /// <summary>The project's preprocessor symbols, which decide what an #if keeps.</summary>
    public IReadOnlyList<string> Defines { get; init; } = [];

    /// <summary>Whether the file is generated code: read for what it declares, never reported on.</summary>
    public bool Generated { get; init; }

    /// <summary>The file's syntax tree, read with the project's symbols.</summary>
    public SyntaxTree Parse() =>
        CSharpSyntaxTree.ParseText(Text, CSharpParseOptions.Default.WithPreprocessorSymbols(Defines), Path);
}
