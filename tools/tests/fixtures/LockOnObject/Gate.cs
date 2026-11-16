namespace LockOnObject;

// Microsoft's managed threading page: a dedicated System.Threading.Lock with the lock statement (IDE0330).
internal sealed class Gate
{
    private readonly object _gate = new();
    private int _count;

    internal int Add()
    {
        lock (_gate)
        {
            return ++_count;
        }
    }
}
