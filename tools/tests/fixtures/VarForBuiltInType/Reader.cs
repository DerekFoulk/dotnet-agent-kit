namespace VarForBuiltInType;

// STY-002: a built-in type is always written, even where a cast names it on the right side.
public static class Reader
{
    public static int Length(object value)
    {
        ArgumentNullException.ThrowIfNull(value);
        var text = (string)value;
        return text.Length;
    }
}
