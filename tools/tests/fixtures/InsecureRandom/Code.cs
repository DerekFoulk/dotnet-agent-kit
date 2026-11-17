namespace InsecureRandom;

internal static class Code
{
    internal static int Token() => Random.Shared.Next();
}
