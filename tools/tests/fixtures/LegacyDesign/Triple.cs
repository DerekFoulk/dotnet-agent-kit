namespace LegacyDesign;

// Three type parameters: CA1005.
public sealed class Triple<TFirst, TSecond, TThird>
{
    public TFirst? First { get; init; }

    public TSecond? Second { get; init; }

    public TThird? Third { get; init; }
}
