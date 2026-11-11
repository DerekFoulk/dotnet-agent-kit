using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.Text;

namespace Kit.CodeShape;

/// <summary>One place where code breaks a CRF-008 limit.</summary>
/// <param name="Path">The source file.</param>
/// <param name="Line">The 1-based line the finding points at.</param>
/// <param name="Column">The 1-based column the finding points at.</param>
/// <param name="Message">What breaks which limit.</param>
internal sealed record Finding(string Path, int Line, int Column, string Message)
{
    /// <summary>A finding at a place in a file's syntax tree.</summary>
    public static Finding At(string path, Location location, string message)
    {
        ArgumentNullException.ThrowIfNull(location);

        LinePosition start = location.GetLineSpan().StartLinePosition;
        return new Finding(path, start.Line + 1, start.Character + 1, message);
    }
}
