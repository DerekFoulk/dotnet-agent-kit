namespace DisposePattern;

// Microsoft's Implement a Dispose method page (STY-003).
internal static class Reader
{
    // CA2000: the reader is never disposed.
    internal static string Read(string path)
    {
        StreamReader reader = new(path);
        return reader.ReadToEnd();
    }
}

// CA1063 and CA1816: Dispose doesn't call Dispose(true) and GC.SuppressFinalize.
internal class Finalized : IDisposable
{
    ~Finalized()
    {
        Dispose(false);
    }

    public void Dispose()
    {
        Dispose(true);
    }

    protected virtual void Dispose(bool disposing)
    {
    }
}

// CA1001: the type owns a disposable field but isn't disposable.
internal sealed class Holder
{
    private readonly CancellationTokenSource _source = new();

    internal bool IsCancelled => _source.IsCancellationRequested;
}
