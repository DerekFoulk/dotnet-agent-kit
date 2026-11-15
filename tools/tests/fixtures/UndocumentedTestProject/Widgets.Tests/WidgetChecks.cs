namespace Widgets.Tests;

// A test project's public class with no XML documentation comment, which must still build: test projects write no
// documentation file (STY-008, ADR-0069). Keep it undocumented.
public static class WidgetChecks
{
    public static bool IsPositive(int value) => value > 0;
}
