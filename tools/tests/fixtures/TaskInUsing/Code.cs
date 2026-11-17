namespace TaskInUsing;

// VSTHRD107: a using statement over a Task disposes the task, not the stream it returns, so the stream is never disposed;
// the C# async page awaits a task (await using, here). VSTHRD107 sees only the statement form; a using declaration,
// which IDE0063 asks for, is code review's to check (STY-011).
internal static class Code
{
    internal static void Open(Func<Task<Stream>> open, Action closed)
    {
        ArgumentNullException.ThrowIfNull(open);
        ArgumentNullException.ThrowIfNull(closed);
        using (open())
        {
        }

        closed();
    }
}
