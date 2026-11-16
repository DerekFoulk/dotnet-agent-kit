namespace ThrowPattern;

// Microsoft's Best practices for exceptions page (STY-003).
internal static class Code
{
    // CA2200: rethrowing the caught exception loses its stack trace.
    internal static void Rethrow()
    {
        try
        {
            Work();
        }
        catch (InvalidOperationException e)
        {
            throw e;
        }
    }

    // CA2201: a reserved, too general exception type.
    internal static void Reserved() => throw new Exception(nameof(Reserved));

    // CA1510: a hand-written null check, where ArgumentNullException.ThrowIfNull does it.
    internal static void Null(string? text)
    {
        if (text is null)
        {
            throw new ArgumentNullException(nameof(text));
        }
    }

    // CA1511: a hand-written empty check, in the shape the CA1511 page shows.
    internal static void Empty(string text)
    {
        if (string.IsNullOrEmpty(text))
        {
            throw new ArgumentException("", nameof(text));
        }
    }

    // CA1512: a hand-written range check.
    internal static void Range(int number)
    {
        if (number < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(number));
        }
    }

    private static void Work()
    {
    }
}

// CA1513: a hand-written disposed check.
internal sealed class Resource
{
    private bool _closed;

    internal void Close() => _closed = true;

    internal void Use()
    {
        if (_closed)
        {
            throw new ObjectDisposedException(GetType().FullName);
        }
    }
}
