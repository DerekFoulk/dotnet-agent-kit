namespace Widgets.Tests;

public static class Waiter
{
    public static async Task<int> DoubleLaterAsync(int value, CancellationToken cancellationToken)
    {
        await Task.Delay(1, cancellationToken);
        return value * 2;
    }
}
