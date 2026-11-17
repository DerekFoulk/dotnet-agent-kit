namespace TaskDropped;

// VSTHRD110: a Task dropped in a method that isn't async, where CS4014 doesn't look; its exception is lost and nothing
// waits for it to finish.
internal static class Code
{
    internal static void Save(Func<Task> write)
    {
        ArgumentNullException.ThrowIfNull(write);
        write();
    }
}
