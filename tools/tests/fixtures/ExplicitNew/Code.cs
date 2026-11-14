using System.Text;

namespace ExplicitNew;

// STY-007: a target-typed new where the type is apparent (IDE0090).
public static class Builder
{
    public static string Build(string text)
    {
        StringBuilder builder = new StringBuilder();
        builder.Append(text);
        return builder.ToString();
    }
}
