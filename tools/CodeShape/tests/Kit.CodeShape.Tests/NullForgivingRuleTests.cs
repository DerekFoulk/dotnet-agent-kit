namespace Kit.CodeShape.Tests;

// The nullable pages: use the null-forgiving operator sparingly; CRF-001 labels each safety net that stays (STY-005).
public sealed class NullForgivingRuleTests
{
    private const string Message =
        "The null-forgiving operator needs // CRF-001 safety net: <reason> on its line or the line above (STY-005).";

    [Fact]
    public void AnUnlabelledOperatorIsReportedAtTheOperator() =>
        NullForgivingRule.Check(new SourceFile("Name.cs", "class Name\n{\n    string? _text;\n    int Length() => _text!.Length;\n}\n"))
            .Should().ContainSingle().Which.Should().BeEquivalentTo(new { Path = "Name.cs", Line = 4, Column = 26, Message });

    [Fact]
    public void ANullOrDefaultInitializerIsReportedToo() =>
        NullForgivingRule.Check(new SourceFile("Init.cs", "class Init { string _a = null!; string _b = default!; }"))
            .Should().HaveCount(2);

    [Theory]
    [InlineData("    int Length() => _text!.Length; // CRF-001 safety net: set in the constructor's only caller.\n")]
    [InlineData("    // CRF-001 safety net: set in the constructor's only caller.\n    int Length() => _text!.Length;\n")]
    public void ALabelOnItsLineOrTheLineAboveCoversIt(string member) =>
        NullForgivingRule.Check(new SourceFile("Name.cs", $"class Name\n{{\n    string? _text;\n{member}}}\n")).Should().BeEmpty();

    [Fact]
    public void AnotherCommentDoesNotCoverIt() =>
        NullForgivingRule.Check(new SourceFile("Name.cs", "class Name\n{\n    string? _text;\n    // never null here\n    int Length() => _text!.Length;\n}\n"))
            .Should().ContainSingle();

    // Review 1: in a chain over several lines, the label goes on the operator's line or the one above it.
    [Fact]
    public void TheLabelIsLookedForAroundTheOperatorNotTheStartOfItsOperand() =>
        NullForgivingRule.Check(new SourceFile("Chain.cs", string.Join('\n',
            "class Chain",
            "{",
            "    int Length(Chain c) => c",
            "        .Find()",
            "        // CRF-001 safety net: Find never returns null for a chain it built.",
            "        .ToString()!.Length;",
            "    object? Find() => this;",
            "}"))).Should().BeEmpty();

    // Review 1: only a comment is a label, not the same text in a string.
    [Fact]
    public void TheLabelsTextInAStringIsNoLabel() =>
        NullForgivingRule.Check(new SourceFile("Text.cs", "class Text { string? _t; string Show() => \"// CRF-001 safety net: x\" + _t!.Length; }"))
            .Should().ContainSingle();

    [Fact]
    public void ALogicalNotIsNotTheOperator() =>
        NullForgivingRule.Check(new SourceFile("Not.cs", "class Not { bool Flip(bool a) => !a; bool Differ(int a, int b) => a != b; }")).Should().BeEmpty();
}
