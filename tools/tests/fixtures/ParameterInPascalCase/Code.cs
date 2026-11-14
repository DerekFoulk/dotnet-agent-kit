namespace ParameterInPascalCase;

// STY-007: parameters are camelCase (IDE1006).
public static class Greeter
{
    public static string Greet(string Name)
    {
        ArgumentNullException.ThrowIfNull(Name);
        return "Hello, " + Name;
    }
}
