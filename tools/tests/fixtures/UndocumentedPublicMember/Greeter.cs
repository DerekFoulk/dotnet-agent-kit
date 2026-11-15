namespace UndocumentedPublicMember;

/// <summary>Greets people by name.</summary>
public static class Greeter
{
    // A public member with no XML documentation comment, which CS1591 reports once the project writes its
    // documentation file (STY-008).
    public static string Greet(string name)
    {
        ArgumentNullException.ThrowIfNull(name);
        return "Hello, " + name + "!";
    }
}
