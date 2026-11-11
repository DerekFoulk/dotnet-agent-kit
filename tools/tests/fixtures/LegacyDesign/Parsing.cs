namespace LegacyDesign;

// An out parameter outside the Try pattern (CA1021) and ref parameters (CA1045).
public static class Parsing
{
    public static void Split(string text, out string head)
    {
        ArgumentNullException.ThrowIfNull(text);
        head = text.Split(' ')[0];
    }

    public static void Swap(ref int first, ref int second) => (first, second) = (second, first);
}
