namespace Kit.CodeShape.Tests;

public sealed class NestingRuleTests
{
    [Fact]
    public void AMemberNestedFiveLevelsDeepIsReportedAtItsDeepestStatement()
    {
        SourceFile file = new("Deep.cs", """
            class Deep
            {
                void Run(int a)
                {
                    if (a > 0)
                    {
                        if (a > 1)
                        {
                            if (a > 2)
                            {
                                if (a > 3)
                                {
                                    if (a > 4)
                                    {
                                        a++;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            """);

        IEnumerable<Finding> findings = NestingRule.Check(file);

        findings.Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Deep.cs",
            Line = 15,
            Column = 29,
            Message = "Run nests 5 levels deep; the limit is 4 (CRF-008).",
        });
    }

    [Fact]
    public void AMemberNestedFourLevelsDeepIsWithinTheLimit()
    {
        SourceFile file = new("AtLimit.cs", """
            class AtLimit
            {
                void Run(int a)
                {
                    if (a > 0)
                    {
                        if (a > 1)
                        {
                            if (a > 2)
                            {
                                if (a > 3)
                                {
                                    a++;
                                }
                            }
                        }
                    }
                }
            }
            """);

        NestingRule.Check(file).Should().BeEmpty();
    }
}
