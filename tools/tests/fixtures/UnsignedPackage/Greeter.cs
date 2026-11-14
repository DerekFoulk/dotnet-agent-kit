namespace UnsignedPackage;

public static class Greeter
{
    public static string Greet(string name)
    {
        ArgumentNullException.ThrowIfNull(name);
        string trimmed = name.Trim();
        return "Hello, " + trimmed + "!";
    }
}
