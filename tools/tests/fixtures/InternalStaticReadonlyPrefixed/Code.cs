namespace InternalStaticReadonlyPrefixed;

// STY-007: an internal static readonly field takes PascalCase, not the s_ prefix, which CA1707 would fail too.
internal static class Catalog
{
    internal static readonly Uri s_source = new("https://example.com/");
}
