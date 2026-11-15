namespace InternalStructWithoutEquals;

// FDG: a value type overrides Equals (CA1815), checked on internal types too (STY-009).
internal readonly struct Point(int x)
{
    internal int X { get; } = x;
}
