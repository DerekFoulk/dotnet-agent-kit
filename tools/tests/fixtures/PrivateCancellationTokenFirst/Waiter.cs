namespace PrivateCancellationTokenFirst;

// CA1068 (CancellationToken parameters come last) checks every member by default, private ones included; the Design
// category's api_surface mustn't narrow it (STY-009).
internal static class Waiter
{
    internal static Task WaitTwiceAsync(int milliseconds, CancellationToken cancellationToken) =>
        WaitAsync(cancellationToken, milliseconds * 2);

    private static Task WaitAsync(CancellationToken cancellationToken, int milliseconds) =>
        Task.Delay(milliseconds, cancellationToken);
}
