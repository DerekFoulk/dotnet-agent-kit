using System.Text;

namespace VarWhenApparent;

// STY-002: var only where the type is named on the right side, as dotnet/runtime allows it: a new and a cast.
public static class Joiner
{
    public static string Join(object first, string second)
    {
        var text = (string)first;
        var builder = new StringBuilder();
        builder.Append(text).Append(second);
        return builder.ToString();
    }
}
