namespace Deep;

internal static class Nested
{
    public static int Run(int a)
    {
        if (a > 0) { if (a > 1) { if (a > 2) { if (a > 3) { if (a > 4) { a++; } } } } }
        return a;
    }
}
