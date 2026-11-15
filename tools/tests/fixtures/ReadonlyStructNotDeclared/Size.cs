namespace ReadonlyStructNotDeclared;

// FDG: don't define mutable value types; a struct whose members are all read-only is declared readonly (IDE0250,
// STY-009).
internal struct Size(int width) : IEquatable<Size>
{
    internal int Width { get; } = width;

    public readonly bool Equals(Size other) => Width == other.Width;

    public override readonly bool Equals(object? obj) => obj is Size other && Equals(other);

    public override readonly int GetHashCode() => Width;

    public static bool operator ==(Size left, Size right) => left.Equals(right);

    public static bool operator !=(Size left, Size right) => !left.Equals(right);
}
