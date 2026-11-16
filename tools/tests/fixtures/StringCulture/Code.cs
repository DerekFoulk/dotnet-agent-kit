namespace StringCulture;

// Microsoft's string, display-data and globalization pages: say the culture and the comparison (STY-003).
internal static class Code
{
    // CA1305: a number formatted in the current culture.
    internal static string Format(int number) => number.ToString();

    // CA1307: an overload that takes a StringComparison exists.
    internal static bool Has(string text) => text.Contains('b');

    // CA1309: an invariant-culture comparison, where ordinal is meant.
    internal static int Compare(string left, string right) => string.Compare(left, right, StringComparison.InvariantCulture);

    // CA1310: a culture-sensitive comparison by default.
    internal static bool Starts(string text) => text.StartsWith("bb");

    // CA1311: a case change with no culture.
    internal static string Lower(string text) => text.ToLower();
}
