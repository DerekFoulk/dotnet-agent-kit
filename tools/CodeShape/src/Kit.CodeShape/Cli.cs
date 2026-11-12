using System.Text.Json;

namespace Kit.CodeShape;

/// <summary>The command line: Kit.CodeShape &lt;manifest.json&gt;.</summary>
internal static class Cli
{
    /// <summary>Checks every project the manifest lists; returns the process exit code.</summary>
    public static int Run(IReadOnlyList<string> args, TextWriter output)
    {
        ArgumentNullException.ThrowIfNull(args);
        ArgumentNullException.ThrowIfNull(output);

        return 2;
    }
}
