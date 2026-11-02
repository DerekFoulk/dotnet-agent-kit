namespace Clean;

public static class Greeter
{
    public static string Greet(string name)
    {
        string trimmed = name.Trim();
        return "Hello, " + trimmed + "!";
    }
}
