namespace Kit.CodeShape;

/// <summary>A C# source file of one project: its path and its text.</summary>
/// <param name="Path">Where the file is.</param>
/// <param name="Text">What the file holds.</param>
internal sealed record SourceFile(string Path, string Text);
