namespace Widgets.Benchmarks;

// BenchmarkDotNet runs only public, unsealed benchmark classes, which CA1515 asks an app to make internal (ADR-0062).
/// <summary>A public member of this fixture (STY-008).</summary>
public class WidgetBenchmarks
{
    private readonly int[] _values = [3, 1, 2];

    /// <summary>A public member of this fixture (STY-008).</summary>
    public int Sum() => _values.Sum();
}
