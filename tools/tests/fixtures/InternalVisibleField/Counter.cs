namespace InternalVisibleField;

// FDG: don't provide instance fields that are public or protected (CA1051, a Design rule), checked on internal types
// too (STY-009).
internal sealed class Counter
{
    public int Count;
}

internal static class Use
{
    internal static int Read()
    {
        Counter counter = new() { Count = 1 };
        return counter.Count;
    }
}
