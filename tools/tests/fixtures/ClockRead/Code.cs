namespace ClockRead;

// The clock read directly can't be faked in a test; time comes from an injected TimeProvider (ARC-008).
internal static class Code
{
    internal static DateTime Now() => DateTime.Now;

    internal static DateTime UtcNow() => DateTime.UtcNow;

    internal static DateTime Today() => DateTime.Today;

    internal static DateTimeOffset OffsetNow() => DateTimeOffset.Now;

    internal static DateTimeOffset OffsetUtcNow() => DateTimeOffset.UtcNow;
}
