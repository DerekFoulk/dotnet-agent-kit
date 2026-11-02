namespace UsesVar;

public static class Counter
{
    public static int CountWords(string text)
    {
        var words = text.Split(' ');
        return words.Length;
    }
}
