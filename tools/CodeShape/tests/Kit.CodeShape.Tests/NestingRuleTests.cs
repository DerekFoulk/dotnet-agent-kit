namespace Kit.CodeShape.Tests;

public sealed class NestingRuleTests
{
    [Fact]
    public void AMemberNestedFourLevelsDeepIsReportedAtItsDeepestStatement()
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
                                    a++;
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
            Line = 13,
            Column = 25,
            Message = "Run nests 4 levels deep; the limit is 3 (CRF-011).",
        });
    }

    [Fact]
    public void AMemberNestedThreeLevelsDeepIsWithinTheLimit()
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
                                a++;
                            }
                        }
                    }
                }
            }
            """);

        NestingRule.Check(file).Should().BeEmpty();
    }

    // Three ifs deep around a statement; whatever wraps it decides whether it's over the limit.
    private const string ThreeIfs = "if (a > 1) { if (a > 2) { if (a > 3) { a++; } } }";

    [Theory]
    [InlineData("switch (a) { case 0: ", " break; }")]
    [InlineData("for (;;) { ", " }")]
    [InlineData("foreach (int x in new int[0]) { ", " }")]
    [InlineData("foreach (var (x, y) in new (int, int)[0]) { ", " }")]
    [InlineData("while (a > 0) { ", " }")]
    [InlineData("do { ", " } while (a > 0);")]
    [InlineData("try { ", " } finally { }")]
    [InlineData("try { } catch { ", " }")]
    [InlineData("if (a > 0) { } else { ", " }")]
    [InlineData("if (a > 0) { System.Action f = () => { ", " }; }")]
    [InlineData("if (a > 0) { void Local() { ", " } Local(); }")]
    public void EachControlFlowStatementAddsALevelAndLambdasKeepCounting(string before, string after)
    {
        NestingRule.Check(ThreeIfsIn(before, after)).Should().ContainSingle()
            .Which.Message.Should().Be("Run nests 4 levels deep; the limit is 3 (CRF-011).");
    }

    [Theory]
    [InlineData("{ ", " }")]
    [InlineData("using (System.IDisposable d = null!) { ", " }")]
    [InlineData("lock (this) { ", " }")]
    [InlineData("checked { ", " }")]
    [InlineData("System.Action f = () => { ", " };")]
    public void BlocksUsingLockCheckedAndLambdasAddNoLevel(string before, string after) =>
        NestingRule.Check(ThreeIfsIn(before, after)).Should().BeEmpty();

    [Fact]
    public void AnElseIfContinuesItsChainWithoutALevel()
    {
        SourceFile file = new("Chain.cs", """
            class Chain
            {
                void Run(int a)
                {
                    if (a > 9) { } else if (a > 8) { } else if (a > 7) { if (a > 2) { if (a > 3) { a++; } } }
                }
            }
            """);

        NestingRule.Check(file).Should().BeEmpty();
    }

    [Theory]
    [InlineData("Kinds(int a) { OVER }", "Kinds")]
    [InlineData("~Kinds() { int a = 0; OVER }", "~Kinds")]
    [InlineData("public static Kinds operator +(Kinds k, int a) { OVER return k; }", "operator +")]
    [InlineData("public static explicit operator int(Kinds k) { int a = 0; OVER return a; }", "explicit operator int")]
    [InlineData("int P { get { int a = 0; OVER return a; } }", "P.get")]
    [InlineData("int this[int a] { set { OVER } }", "this[].set")]
    [InlineData("event System.Action E { add { int a = 0; OVER } remove { } }", "E.add")]
    [InlineData("System.Action P => () => { int a = 0; OVER };", "P")]
    [InlineData("System.Action this[int a] => () => { OVER };", "this[]")]
    public void EveryMemberWithABodyIsMeasuredAndNamed(string member, string name)
    {
        SourceFile file = new("Kinds.cs", $$"""
            class Kinds
            {
                {{member}}
            }
            """.Replace("OVER", $"if (a > 0) {{ {ThreeIfs} }}", StringComparison.Ordinal));

        NestingRule.Check(file).Should().ContainSingle()
            .Which.Message.Should().Be($"{name} nests 4 levels deep; the limit is 3 (CRF-011).");
    }

    [Fact]
    public void TopLevelStatementsAreMeasuredAsOneMember()
    {
        SourceFile file = new("Program.cs", $"int a = 0; if (a > 0) {{ {ThreeIfs} }}");

        NestingRule.Check(file).Should().ContainSingle()
            .Which.Message.Should().Be("top-level statements nests 4 levels deep; the limit is 3 (CRF-011).");
    }

    // A method whose body is three nested ifs, with the given text before and after them.
    private static SourceFile ThreeIfsIn(string before, string after) => new("Wrapped.cs", $$"""
        class Wrapped
        {
            void Run(int a)
            {
                {{before}}{{ThreeIfs}}{{after}}
            }
        }
        """);
}
