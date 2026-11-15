using System.Text;

namespace VarWhenApparent;

// STY-002: var only where the type is named on the right side, as dotnet/runtime allows it: a new and a cast. A
// built-in type such as string or int is always written, even after a cast (csharp_style_var_for_built_in_types).
/// <summary>A public member of this fixture (STY-008).</summary>
public static class Joiner
{
    /// <summary>A public member of this fixture (STY-008).</summary>
    public static string Join(object first, string second)
    {
        ArgumentNullException.ThrowIfNull(first);
        var address = (Uri)first;
        var builder = new StringBuilder();
        builder.Append(address.Host).Append(second);
        return builder.ToString();
    }
}
