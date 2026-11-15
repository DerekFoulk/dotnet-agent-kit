namespace InternalIncorrectSuffix;

// FDG: don't use the Impl suffix (CA1711, a Naming rule), checked on internal types too (STY-009).
internal static class ParserImpl
{
    internal static int Parse(string text) => int.Parse(text, System.Globalization.CultureInfo.InvariantCulture);
}
