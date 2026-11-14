namespace ArrayInitializer;

// STY-007: a collection expression instead of an array creation (IDE0300).
public static class Numbers
{
    public static int Sum()
    {
        int[] values = new int[] { 1, 2, 3 };
        return values.Sum();
    }
}
