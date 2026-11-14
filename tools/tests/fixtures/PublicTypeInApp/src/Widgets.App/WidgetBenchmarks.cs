namespace Widgets.App;

// BenchmarkDotNet runs only public, unsealed benchmark classes, which CA1515 asks an app to make internal (ADR-0062).
public class WidgetBenchmarks
{
    private readonly int[] _values = [3, 1, 2];

    public int Sum() => _values.Sum();
}
