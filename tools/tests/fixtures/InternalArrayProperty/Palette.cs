namespace InternalArrayProperty;

// FDG: properties don't return arrays (CA1819), checked on internal types too (STY-009).
internal sealed class Palette
{
    internal int[] Colors { get; } = [1, 2];
}

internal static class Use
{
    internal static int First() => new Palette().Colors[0];
}
