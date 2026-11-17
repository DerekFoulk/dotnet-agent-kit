namespace PrivateStaticReadonlyUnprefixed;

// STY-007: a private static field keeps the s_ prefix, readonly or not, as the identifier names page asks.
internal static class Catalog
{
    private static readonly Uri Source = new("https://example.com/");

    internal static Uri Read() => Source;
}
