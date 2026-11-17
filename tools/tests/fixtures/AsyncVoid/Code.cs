namespace AsyncVoid;

// The C# async page: async void only for event handlers, and no async lambda where a void delegate is expected.
internal static class Code
{
    // VSTHRD100: an exception here can't be caught; it crashes the process.
    internal static async void FireAsync() => await Task.Yield();

    // VSTHRD101: List<T>.ForEach takes an Action, so the lambda is async void.
    internal static void ForEachAsync(IReadOnlyCollection<int> items) => items.ToList().ForEach(async item => await Task.Delay(item));
}
