namespace ConsoleApp;

// An async entry point keeps the name Main (IDE1006 leaves it alone).
internal static class Program
{
    private static async Task Main() => await Task.Yield();
}
