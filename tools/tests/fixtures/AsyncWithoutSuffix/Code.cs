namespace AsyncWithoutSuffix;

// The TAP and C# async pages: an async method's name ends in Async (IDE1006).
internal static class Code
{
    internal static async Task Load() => await Task.Yield();
}
