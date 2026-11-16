namespace BlockingEscape;

// Where blocking can't be avoided, GetAwaiter().GetResult() is the C# async page's preferred form: it keeps the
// original exception, unwrapped (STY-011).
internal static class Code
{
    internal static int Result(Task<int> task)
    {
        ArgumentNullException.ThrowIfNull(task);
        return task.GetAwaiter().GetResult();
    }
}
