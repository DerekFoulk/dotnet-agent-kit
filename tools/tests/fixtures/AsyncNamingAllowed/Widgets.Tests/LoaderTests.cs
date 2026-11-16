namespace Widgets.Tests;

// Test methods are named for the behavior they check (TST-010), with no Async suffix, which VSTHRD200 would ask for.
public static class LoaderTests
{
    public static async Task LoadsAWidget() => await Task.Yield();
}
