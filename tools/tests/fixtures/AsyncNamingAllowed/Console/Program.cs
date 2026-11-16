namespace ConsoleApp;

// An async entry point keeps the name Main (IDE1006 leaves it alone). A private constant stays PascalCase beside the
// async rule: const implies static, and without the kit's intersection rule the s_ rule for static fields claims it.
internal static class Program
{
    private const int DelayMilliseconds = 1;

    private static async Task Main() => await Task.Delay(DelayMilliseconds);
}
