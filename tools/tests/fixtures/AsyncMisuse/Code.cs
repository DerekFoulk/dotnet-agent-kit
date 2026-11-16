namespace AsyncMisuse;

// Microsoft's TAP pages: consuming and implementing the task-based asynchronous pattern (STY-003).
internal static class Code
{
    // CA2008: a continuation with no TaskScheduler.
    internal static Task ContinueAsync(Task task) => task.ContinueWith(_ => { });

    // CA2016: the token isn't passed on.
    internal static async Task WaitAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        await Task.Delay(1).ConfigureAwait(false);
    }

    // CA1849: a blocking call inside an async method, where an async one exists.
    internal static async Task<string> ReadAsync(string path)
    {
        await Task.Yield();
        return File.ReadAllText(path);
    }

    // CS4014: a task started and not awaited.
    internal static async Task FireAsync()
    {
        Task.Delay(1);
        await Task.Yield();
    }

    // CA2012: a ValueTask thrown away.
    internal static void Discard() => _ = CountAsync();

    private static ValueTask<int> CountAsync() => ValueTask.FromResult(1);
}
