namespace NullableViolation;

public static class Lookup
{
    public static int Length()
    {
        string name = null;
        return name.Length;
    }
}
