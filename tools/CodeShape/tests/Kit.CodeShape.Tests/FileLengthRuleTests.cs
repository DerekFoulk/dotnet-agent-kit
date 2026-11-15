namespace Kit.CodeShape.Tests;

public sealed class FileLengthRuleTests
{
    [Fact]
    public void AFileOf401LinesIsReportedAtItsFirstLineOverTheLimit() =>
        FileLengthRule.Check(Lines("Long.cs", 401, "\n")).Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Long.cs",
            Line = 401,
            Column = 1,
            Message = "The file has 401 lines; the limit is 400 (CRF-011).",
        });

    [Theory]
    [InlineData("\n")]
    [InlineData("\r\n")]
    public void AFileOf400LinesIsWithinTheLimitWhateverItsLineEndings(string newline) =>
        FileLengthRule.Check(Lines("AtLimit.cs", 400, newline)).Should().BeEmpty();

    [Fact]
    public void AFinalNewlineEndsTheLastLineWithoutStartingAnother() =>
        FileLengthRule.Check(Lines("Ended.cs", 400, "\n", finalNewline: true)).Should().BeEmpty();

    private static SourceFile Lines(string path, int count, string newline, bool finalNewline = false) =>
        new(path, string.Join(newline, Enumerable.Repeat("// a line", count)) + (finalNewline ? newline : string.Empty));
}
