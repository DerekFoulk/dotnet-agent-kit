namespace PrivateArgumentException;

// CA2208 (instantiate argument exceptions correctly) checks every member by default, private ones included; the Usage
// category's api_surface mustn't narrow it (STY-009).
internal static class Guard
{
    internal static int Twice(int value) => Positive(value) * 2;

    private static int Positive(int value) => value > 0 ? value : throw new ArgumentOutOfRangeException("count");
}
