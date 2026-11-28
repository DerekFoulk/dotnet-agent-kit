namespace HandWrittenInMigrations.Migrations;

/// <summary>A file of the app's own in a Migrations folder, which dotnet ef didn't write.</summary>
public static class Counter
{
    /// <summary>Counts the words in a text.</summary>
    /// <param name="text">The text.</param>
    /// <returns>The number of words.</returns>
    public static int CountWords(string text)
    {
        var words = text.Split(' ');
        return words.Length;
    }
}
