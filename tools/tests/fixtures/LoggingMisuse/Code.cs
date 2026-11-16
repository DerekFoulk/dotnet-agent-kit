using Microsoft.Extensions.Logging;

namespace LoggingMisuse;

// Microsoft's high-performance logging and logging source generation pages (STY-003).
internal static class Code
{
    // CA1848: a logger extension method, where a [LoggerMessage] method does it without boxing.
    internal static void Extension(ILogger logger, int value) => logger.LogInformation("Value {Value}", value);

    // CA2254: a template that varies between calls.
    internal static void Dynamic(ILogger logger, int value) => logger.LogInformation($"Value {value}");

    // CA1727: a placeholder that isn't PascalCase.
    internal static void Lower(ILogger logger, int value) => logger.LogInformation("Value {value}", value);

    // CA1873: an argument computed even when the level is off.
    internal static void Expensive(ILogger logger) => logger.LogDebug("Values {Values}", Compute());

    private static string Compute() => string.Join(',', Enumerable.Range(0, 10));
}
