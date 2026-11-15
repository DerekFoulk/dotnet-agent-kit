namespace Clean;

/// <summary>A public member of this fixture (STY-008).</summary>
public static class Greeter
{
    /// <summary>A public member of this fixture (STY-008).</summary>
    public static string Greet(string name)
    {
        ArgumentNullException.ThrowIfNull(name);
        string trimmed = name.Trim();
        return "Hello, " + trimmed + "!";
    }
}
