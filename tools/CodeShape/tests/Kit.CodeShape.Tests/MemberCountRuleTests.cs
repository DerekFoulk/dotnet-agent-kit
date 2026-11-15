namespace Kit.CodeShape.Tests;

public sealed class MemberCountRuleTests
{
    [Fact]
    public void ATypeWithTwentyOneMembersIsReportedOnceAtItsName() =>
        MemberCountRule.Check([new SourceFile("Wide.cs", $"class Wide {{ {Methods(21)}}}")]).Should().ContainSingle()
            .Which.Should().BeEquivalentTo(new
            {
                Path = "Wide.cs",
                Line = 1,
                Column = 7,
                Message = "Wide has 21 members; the limit is 20 (CRF-011).",
            });

    [Fact]
    public void ATypeWithTwentyMembersIsWithinTheLimit() =>
        MemberCountRule.Check([new SourceFile("AtLimit.cs", $"class AtLimit {{ {Methods(20)}}}")]).Should().BeEmpty();

    // Each field and event a declaration names is a member; so is every other kind a type declares.
    [Theory]
    [InlineData("int _a, _b;", 2)]
    [InlineData("event System.Action A, B;", 2)]
    [InlineData("event System.Action E { add { } remove { } }", 1)]
    [InlineData("int P { get; set; }", 1)]
    [InlineData("int this[int i] => i;", 1)]
    [InlineData("Kinds() { }", 1)]
    [InlineData("static Kinds() { }", 1)]
    [InlineData("~Kinds() { }", 1)]
    [InlineData("public static Kinds operator +(Kinds k, int a) => k;", 1)]
    [InlineData("public static explicit operator int(Kinds k) => 0;", 1)]
    public void EveryKindOfMemberCounts(string member, int members) =>
        MemberCountRule.Check([new SourceFile("Kinds.cs", $"class Kinds {{ {member} {Methods(21 - members)}}}")]).Should().ContainSingle()
            .Which.Message.Should().Be("Kinds has 21 members; the limit is 20 (CRF-011).");

    // A record's positional parameters are properties the compiler declares for it, unless the record declares the
    // property itself; a class's primary constructor parameters aren't members.
    [Theory]
    [InlineData("record Point(int X, int Y) { ", 19, 1)]
    [InlineData("record struct Point(int X, int Y) { ", 19, 1)]
    [InlineData("record Point(int X, int Y) { public int X { get; } = X; ", 18, 0)]
    [InlineData("class Point(int x, int y) { ", 20, 0)]
    public void ARecordsPositionalParametersAreItsProperties(string opening, int methods, int findings) =>
        MemberCountRule.Check([new SourceFile("Point.cs", $"{opening}{Methods(methods)}}}")]).Should().HaveCount(findings);

    private static string Methods(int count) => string.Concat(Enumerable.Range(0, count).Select(i => $"void M{i}() {{ }} "));
}
