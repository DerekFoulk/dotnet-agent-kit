namespace PureRandomness;

// A pure assembly gets its randomness through an injected abstraction, so its tests are deterministic (ARC-008); it
// keeps every project's bans too, such as the clock.
internal static class Code
{
    internal static int Shared() => Random.Shared.Next();

    internal static int Seeded() => new Random(1).Next();

    internal static int Secure() => System.Security.Cryptography.RandomNumberGenerator.GetInt32(10);

    internal static Guid NewId() => Guid.NewGuid();

    internal static Guid NewVersion7() => Guid.CreateVersion7();

    internal static Guid NewVersion7At(DateTimeOffset at) => Guid.CreateVersion7(at);

    internal static DateTime Now() => DateTime.Now;
}
