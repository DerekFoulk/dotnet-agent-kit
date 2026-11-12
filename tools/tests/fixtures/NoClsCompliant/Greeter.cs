namespace NoClsCompliant;

public static class Greeter
{
    public static string Greet(string name)
    {
        ArgumentNullException.ThrowIfNull(name);
        return "Hello, " + name + "!";
    }
}
