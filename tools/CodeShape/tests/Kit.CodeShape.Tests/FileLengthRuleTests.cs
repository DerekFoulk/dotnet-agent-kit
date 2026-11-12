namespace Kit.CodeShape.Tests;

public sealed class FileLengthRuleTests
{
    [Fact]
    public void AFileOf801LinesIsReportedAtItsFirstLineOverTheLimit() =>
        FileLengthRule.Check(Lines("Long.cs", 801, "\n")).Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Long.cs",
            Line = 801,
            Column = 1,
            Message = "The file has 801 lines; the limit is 800 (CRF-011).",
        });

    [Theory]
    [InlineData("\n")]
    [InlineData("\r\n")]
    public void AFileOf800LinesIsWithinTheLimitWhateverItsLineEndings(string newline) =>
        FileLengthRule.Check(Lines("AtLimit.cs", 800, newline)).Should().BeEmpty();

    [Fact]
    public void AFinalNewlineEndsTheLastLineWithoutStartingAnother() =>
        FileLengthRule.Check(Lines("Ended.cs", 800, "\n", finalNewline: true)).Should().BeEmpty();

    private static SourceFile Lines(string path, int count, string newline, bool finalNewline = false) =>
        new(path, string.Join(newline, Enumerable.Repeat("// a line", count)) + (finalNewline ? newline : string.Empty));
}
