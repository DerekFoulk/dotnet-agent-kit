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

    private static string Methods(int count) => string.Concat(Enumerable.Range(0, count).Select(i => $"void M{i}() {{ }} "));
}
